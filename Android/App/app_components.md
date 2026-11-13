# Android app components

**App components** are the entry points through which the Android system enters an app.
The system creates, starts, pauses and destroys them depending on what the user does and how much memory the device has.
An Android app has no single `main()`: the system starts the process and instantiates whichever component is needed (a screen, a service, a receiver, a provider).

There are four component types. Each has its own base class, manifest element and lifecycle.

## 1. The four components

| Component | Base class | Manifest element | Has UI? | Started by |
| --- | --- | --- | --- | --- |
| Activity | `Activity` (usually `AppCompatActivity` / `ComponentActivity`) | `<activity>` | Yes | `startActivity()`, the launcher, other apps |
| Service | `Service` | `<service>` | No | `startService()`, `startForegroundService()`, `bindService()` |
| Broadcast receiver | `BroadcastReceiver` | `<receiver>`, or `registerReceiver()` at runtime | No | Broadcast intents |
| Content provider | `ContentProvider` | `<provider>` | No | `ContentResolver` calls on the provider's `content://` URI |

### 1.1 Activity

+ One screen with a UI, like a window in a desktop app.
  An email app might have one activity for the inbox, one for reading a message, and one for writing a message.
  Modern apps often use a single activity and switch screens with fragments or Jetpack Compose navigation.
+ It handles user input: taps, typing, navigation.
+ Lifecycle: `onCreate` → `onStart` → `onResume` → `onPause` → `onStop` → `onDestroy`.
  The system calls these as the user moves between screens and apps, and may destroy a stopped activity (or its whole process) to reclaim memory.
+ A configuration change (for example, rotation) destroys and re-creates the activity by default.
  Keep UI state in a `ViewModel` so it survives that (see [app_architecture.md](app_architecture.md)).

### 1.2 Service

+ A component without a UI, for work that must outlive the screen: playing music, a long download, or an API that other apps bind to.
+ A service runs on the app's **main thread** by default. It is not a thread.
  Run blocking work (network, disk, decoding) on a worker thread or in coroutines inside the service.
+ Two ways to use it:
  + **Started** (`startService()` / `startForegroundService()`): runs until it calls `stopSelf()` or someone calls `stopService()`, even after the activity that started it is destroyed.
  + **Bound** (`bindService()`): runs only while at least one client is bound, and offers a client–server interface (over Binder for other apps).
+ Since Android 8, an app in the background can't start a plain background service.
  User-visible long work runs as a **foreground service** with a notification; since Android 14 it must also declare a `foregroundServiceType` (for example, `mediaPlayback`).
  For deferrable work, use WorkManager instead.
  Details: [app_background_limits.md](app_background_limits.md).

### 1.3 Broadcast receiver

+ Lets the system (or other apps) deliver events to the app outside the normal user flow: boot completed, power connected, connectivity changed, locale changed, and so on.
+ Two ways to register:
  + **In the manifest** (`<receiver>`): can be started even when the app isn't running.
    Since Android 8, manifest receivers no longer get most **implicit** broadcasts; only a list of exempt ones such as `BOOT_COMPLETED`.
  + **At runtime** (`registerReceiver()`): only while the registering component (and the process) is alive.
    Apps that target Android 14 must pass `RECEIVER_EXPORTED` or `RECEIVER_NOT_EXPORTED` for non-system broadcasts.
+ `onReceive()` runs on the main thread and must return quickly (within about 10 seconds).
  For longer work, use `goAsync()` for a short task, or hand it to WorkManager or a service.
+ A receiver has no UI. It usually posts a notification or starts other work.
  Starting an activity from the background is restricted since Android 10.

### 1.4 Content provider

+ Manages a set of app data and exposes it to other apps (or other processes of the same app) through a `content://` URI.
+ Clients never call the provider class directly. They use `ContentResolver` (`query()`, `insert()`, `update()`, `delete()`, `openFileDescriptor()`), and the calls cross processes over Binder.
+ The provider controls access with permissions (`android:readPermission`, `android:writePermission`) and temporary per-URI grants.
+ The system ships several providers, for example the Contacts Provider (`ContactsContract`) and `MediaStore`.
+ An app doesn't need a provider for its own private data; use Room or files.
  Write one only to share data with other apps, or use `FileProvider` to share files.
  Details: [ContentProvider_sharing.md](ContentProvider_sharing.md).

## 2. The manifest

Every activity, service and content provider **must** be declared in `AndroidManifest.xml`.
Broadcast receivers are the exception: they can be declared there or registered at runtime.
The package manager reads the manifest at install time, so the system knows the app's components, their intent filters, and the permissions they need without running any app code.

In a Gradle project the manifest is in the module's source set (`app/src/main/AndroidManifest.xml`), not at the project root.

```xml
<application ...>
    <activity android:name=".MainActivity" android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent-filter>
    </activity>
    <service
        android:name=".PlaybackService"
        android:exported="false"
        android:foregroundServiceType="mediaPlayback" />
    <receiver android:name=".BootReceiver" android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
        </intent-filter>
    </receiver>
    <provider
        android:name=".NotesProvider"
        android:authorities="com.example.notes.provider"
        android:exported="false" />
</application>
```

`BOOT_COMPLETED` also needs the `RECEIVE_BOOT_COMPLETED` permission, and `mediaPlayback` needs `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
More on the manifest: [AndroidManifest.md](AndroidManifest.md).

## 3. Intents: how components start each other

An **Intent** is a message that asks for an action from a component, like an envelope with instructions.
Activities, services and broadcast receivers are started with intents; content providers are reached through `ContentResolver` instead.

+ **Explicit intent**: names the target class, for example opening a detail screen in the same app.
+ **Implicit intent**: names only an action (and data), and the system finds a component whose intent filter matches, for example opening a web URL or sharing text.

```kotlin
// Explicit: start a screen in this app
startActivity(Intent(this, DetailActivity::class.java).putExtra("id", 42))

// Implicit: let any app that can show a web page handle it
startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://developer.android.com")))
```

An intent filter is not a security boundary: an exported component can be started with an explicit intent, whatever its filter says.
Set `android:exported="false"` on internal components.

## 4. Example: a music player

How the four components work together in a music streaming app:

1. **Activity (UI)**: the user taps *Play*.
   The activity sends an intent to (or binds to) the playback service.
2. **Service (background work)**: the playback service runs as a foreground service with a media notification and streams the audio on worker threads.
   It lives in a service, not in the activity, because it must keep playing after the user leaves the screen or the activity is destroyed.
3. **Broadcast receiver (system event)**: the user unplugs the headphones.
   The system sends `AudioManager.ACTION_AUDIO_BECOMING_NOISY`, and a receiver that the service registered at runtime pauses playback.
   (Media3's player can handle this itself with `setHandleAudioBecomingNoisy(true)`.)
4. **Content provider (data)**: the user shares the current song with a friend.
   The app launches the system contact picker (`ACTION_PICK` on `ContactsContract`), which returns a `content://` URI that the app reads through `ContentResolver`.
   The data comes from the system's **Contacts Provider**; the app doesn't need its own provider, and the picker grants access to only the chosen contact.

## 5. Summary of interactions

| From | To | How |
| --- | --- | --- |
| Activity | Activity | `startActivity()` with an explicit or implicit intent |
| Activity | Service | `startForegroundService()` / `startService()`, or `bindService()` for a client–server interface |
| System / other app | Broadcast receiver | A broadcast intent; the receiver posts a notification or schedules work |
| Activity / Service | Content provider | `ContentResolver` calls on a `content://` URI, checked against the provider's permissions |

## Related notes

+ [AndroidManifest.md](AndroidManifest.md), [android_class_hierarchy.md](android_class_hierarchy.md), [app_architecture.md](app_architecture.md)
+ [app_background_limits.md](app_background_limits.md), [mediaPlayer_note.md](mediaPlayer_note.md)
+ [ContentProvider_sharing.md](ContentProvider_sharing.md), [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md)

## Reference

+ [Application fundamentals](https://developer.android.com/guide/components/fundamentals)
+ [The activity lifecycle](https://developer.android.com/guide/components/activities/activity-lifecycle)
+ [Services overview](https://developer.android.com/develop/background-work/services)
+ [Foreground services](https://developer.android.com/develop/background-work/services/fgs)
+ [Broadcasts overview](https://developer.android.com/develop/background-work/background-tasks/broadcasts)
+ [Content providers](https://developer.android.com/guide/topics/providers/content-providers)
+ [Intents and intent filters](https://developer.android.com/guide/components/intents-filters)
