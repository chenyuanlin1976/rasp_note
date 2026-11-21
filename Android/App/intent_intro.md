# Android Intent: explicit, implicit, binding a service, Android 14 rules

An **`Intent`** is a message object that asks another app component for an action:
open a screen (`Activity`), start or bind a `Service`, or deliver a broadcast to a `BroadcastReceiver`.
Content providers are reached through `ContentResolver`, not intents.

Think of an `Intent` as a request slip: **what** to do, or **which** component to reach,
plus optional parameters (data URI, extras, flags).
The system (`ActivityManagerService` with the package manager) reads the slip, finds the target, checks permissions, and delivers it.

## 1. Explicit vs. implicit intents

| Type | How the target is chosen | Typical use |
| --- | --- | --- |
| **Explicit** | Names the exact component: `Intent(context, DetailActivity::class.java)` or `ComponentName("com.example.pwm", "com.example.pwm.PwmControlService")` | A screen in your own app; starting or binding a specific `Service`, e.g. an AIDL service in another app |
| **Implicit** | Names an **action** (e.g. `Intent.ACTION_VIEW`), optionally with data and categories; the system picks a component whose intent filter matches | Open a URL, share content, pick a file |

```kotlin
// Explicit: start a screen in this app
startActivity(Intent(this, DetailActivity::class.java))

// Implicit: any app that can show a web page handles it
startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://developer.android.com")))
```

+ **Services need an explicit intent.** Since Android 5.0 (API 21), `bindService()` and `startService()` with an implicit intent
  throw `IllegalArgumentException`. An action plus `setPackage(...)` counts as explicit.
+ For an implicit `startActivity()`, the target's intent filter must include `android.intent.category.DEFAULT`.
  If nothing matches, `startActivity()` throws `ActivityNotFoundException`; catch it.
+ **Package visibility (Android 11+)**: `startActivity()` with an implicit intent still works,
  but `resolveActivity()` / `queryIntentActivities()` and binding to another app's service need a `<queries>` entry
  ([AndroidManifest.md](AndroidManifest.md#8-package-visibility-queries-android-11)).
+ Apps that target Android 14 can deliver implicit intents only to **exported** components.

## 2. Parts of an `Intent`

| Part | API | Purpose |
| --- | --- | --- |
| Component | `setComponent()`, `setClass()`, `Intent(context, Cls::class.java)` | The exact target class (makes the intent explicit) |
| Package | `setPackage()` | Limits resolution to one app |
| Action | `setAction()`, `Intent(action)` | What to do: `ACTION_VIEW`, `ACTION_SEND`, or a custom string such as `com.example.pwm.action.DUTY_CHANGED` |
| Data and type | `setData()`, `setDataAndType()` | The resource: `tel:`, `https://`, `content://` URI, MIME type |
| Category | `addCategory()` | Extra matching criteria, e.g. `CATEGORY_LAUNCHER`, `CATEGORY_BROWSABLE` |
| Extras | `putExtra()`, `Bundle` | Small key/value arguments |
| Flags | `addFlags()` | How the system handles it, e.g. `FLAG_ACTIVITY_NEW_TASK`, `FLAG_GRANT_READ_URI_PERMISSION` |

+ Extras travel through Binder: a large `Bundle` (the transaction buffer is about 1 MB, shared by the process)
  fails with `TransactionTooLargeException`. Pass a `content://` URI or an ID instead of big data.
+ Prefix custom actions and extra keys with your package name, to avoid clashes with other apps.

## 3. Start an activity with data

```kotlin
// Caller
val intent = Intent(this, DetailActivity::class.java).apply {
    putExtra(DetailActivity.EXTRA_DUTY_PERCENT, 50)
}
startActivity(intent)

// DetailActivity
class DetailActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val duty = intent.getIntExtra(EXTRA_DUTY_PERCENT, 0)
        // ...
    }

    companion object {
        const val EXTRA_DUTY_PERCENT = "com.example.pwm.extra.DUTY_PERCENT"
    }
}
```

Starting an activity from a non-activity `Context` (a service or receiver) needs `FLAG_ACTIVITY_NEW_TASK`,
and is restricted from the background since Android 10 ([app_background_limits.md](app_background_limits.md#6-starting-an-activity-from-the-background)).

## 4. Bind to an AIDL service in another app

A client binds with an explicit intent that names the service's package and class.
The example uses the PWM system app from [../HW/pwm_control.md](../HW/pwm_control.md):

```kotlin
val intent = Intent().setComponent(
    ComponentName("com.example.pwm", "com.example.pwm.PwmControlService")
)
val bound = context.bindService(intent, connection, Context.BIND_AUTO_CREATE)   // false: not found or not visible
```

How the request travels, and where each check happens:

```text
+---------------------------------------------------------------------+
|                         CLIENT APP                                  |
|                                                                     |
|  1. Manifest:                                                       |
|     <uses-permission android:name=                                  |
|         "com.example.permission.CONTROL_PWM" />                     |
|     <queries><package android:name="com.example.pwm" /></queries>   |
|                                                                     |
|  2. bindService(explicit Intent, connection, BIND_AUTO_CREATE)      |
+----------------------------------+----------------------------------+
                                   |  Intent + caller UID/PID (Binder)
                                   v
+---------------------------------------------------------------------+
|              SYSTEM (ActivityManagerService + package manager)      |
|                                                                     |
|  3. Resolve the component and check:                                |
|     - is the package visible to the caller (Android 11+)?           |
|     - does the service exist, with android:exported="true"?         |
|     - does the caller hold the <service> android:permission?        |
|       (signature level: granted at install only if the certs match) |
|     fail -> bindService() returns false or throws SecurityException |
+----------------------------------+----------------------------------+
                                   |  allowed: start the process if needed
                                   v
+---------------------------------------------------------------------+
|                  SERVICE APP (PwmControlService)                    |
|                                                                     |
|  4. onBind(intent): returns IPwmControl.Stub (IBinder)              |
|     - called once per Intent; the system caches the IBinder         |
|     - not inside a Binder call: getCallingUid() is the service's    |
+----------------------------------+----------------------------------+
                                   |  IBinder -> onServiceConnected()
                                   v
+---------------------------------------------------------------------+
|  5. Client calls AIDL methods directly over Binder:                 |
|     pwm.setDutyPercent(50)                                          |
|     -> each method may check Binder.getCallingUid() / certificate   |
+---------------------------------------------------------------------+
```

+ **Top → middle**: the system, not your code, enforces visibility, `exported`, and the `<service>` permission.
  The service never sees a rejected request.
+ **Middle → bottom**: `onBind()` is **not** a per-caller gate. Later clients get the cached `IBinder` without a new `onBind()` call,
  and `Binder.getCallingUid()` there returns the service's own UID. Returning `null` refuses every client
  (they get `onNullBinding()`, API 28+).
+ **Finer checks** (different privileges per method, callers signed with other keys) go into **each AIDL method**:
  [../Signing/signature_permission.md](../Signing/signature_permission.md#3-caller-check-inside-the-service).
+ Full client and service code (`ServiceConnection`, `unbindService()`, threading): [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md).

## 5. Broadcasts

`sendBroadcast(intent)` delivers an intent to every matching `BroadcastReceiver`, e.g. system events (`BOOT_COMPLETED`) or your own status updates.
Scope custom broadcasts tightly instead of broadcasting to every app:

```kotlin
// Only receivers in com.example.client, and only if they hold the permission
val intent = Intent("com.example.pwm.action.DUTY_CHANGED")
    .setPackage("com.example.client")
    .putExtra("com.example.pwm.extra.DUTY_PERCENT", 50)
sendBroadcast(intent, "com.example.permission.CONTROL_PWM")
```

+ Since Android 8, manifest-declared receivers don't get most **implicit** broadcasts.
  Make the broadcast explicit (`setPackage()` / `setComponent()`) or register the receiver at runtime.
+ Apps that target Android 14 must pass `RECEIVER_EXPORTED` or `RECEIVER_NOT_EXPORTED` to `registerReceiver()`
  (except for system broadcasts).
+ To receive only from apps that hold a permission, set `android:permission` on `<receiver>` or pass it to `registerReceiver()`.
+ Boot broadcasts in detail: [boot_completed_receiver.md](boot_completed_receiver.md).

## 6. Android 12–14 rules that affect intents

| Since | Rule (for apps that target that version) | What to do |
| --- | --- | --- |
| Android 12 | Every `PendingIntent` must say `FLAG_IMMUTABLE` or `FLAG_MUTABLE`, otherwise `IllegalArgumentException` | Use `FLAG_IMMUTABLE` unless the receiver must fill in data (inline reply, bubbles) |
| Android 14 | Implicit intents are delivered only to **exported** components | Reach your own non-exported components with an explicit intent |
| Android 14 | A **mutable** `PendingIntent` whose intent names no component or package throws an exception | Make it immutable, or set the component / package |
| Android 14 | `registerReceiver()` must pass `RECEIVER_EXPORTED` or `RECEIVER_NOT_EXPORTED` (except for system-broadcast-only receivers), otherwise `SecurityException` | Use `RECEIVER_NOT_EXPORTED` for app-internal broadcasts; `ContextCompat.registerReceiver()` works on older versions too |
| Android 14 | Broadcasts to **context-registered** receivers of a **cached** app are queued until the app leaves the cached state | For time-critical events, keep the handler in a foreground component, or use a bound service / Binder callback instead of a broadcast |

```kotlin
// Immutable PendingIntent with an explicit target
val pi = PendingIntent.getActivity(
    context, 0,
    Intent(context, DetailActivity::class.java),
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
)

// Receiver for this app's own broadcasts only
ContextCompat.registerReceiver(context, receiver,
    IntentFilter("com.example.pwm.action.DUTY_CHANGED"),
    ContextCompat.RECEIVER_NOT_EXPORTED)
```

+ **Intent redirection**: don't take an `Intent` out of another app's extras and start it with your app's identity;
  that lets the caller reach your non-exported components. Hand a `PendingIntent` across apps instead.
  `StrictMode.VmPolicy.Builder().detectUnsafeIntentLaunch()` (Android 12+) flags such launches.
+ More on background limits: [app_background_limits.md](app_background_limits.md).

## 7. Intents on an embedded device (e.g. RK3566)

On a board with your own system image (kiosk, panel, signage), intents connect your apps with the platform:

+ **Kiosk / custom launcher**: give the main activity `category.HOME` + `category.DEFAULT`, so the system starts it after boot
  and on the Home key ([boot_completed_receiver.md](boot_completed_receiver.md)).

```xml
<activity android:name=".KioskActivity" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.HOME" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>
```

+ **Hardware events from your own system service** (GPIO key, HDMI state, UART): if you broadcast them,
  scope the broadcast with `setPackage()` and a permission, so other apps can't receive them.
  A system app can declare the action as `<protected-broadcast>` in its manifest, so only system processes can send it and no app can spoof it.
  For a steady event stream, a bound service with an AIDL callback is better than broadcasts ([../IPC/AIDL_callback.md](../IPC/AIDL_callback.md)).
+ **Media and large data**: pass a `content://` URI with `FLAG_GRANT_READ_URI_PERMISSION`, never the bytes.
  Video frames and camera streams go through `Surface` / `MediaCodec` ([mediaPlayer_note.md](mediaPlayer_note.md)).

## 8. Checklist


+ Use an explicit intent (component, or action + `setPackage()`) for every service.
+ An external caller can start or bind a component only if it has `android:exported="true"`, the caller holds its `android:permission`,
  and (Android 11+) the caller can see the package.
+ An intent filter isn't a security boundary: an exported component can be reached with an explicit intent whatever its filter says.
  Protect exported components with a permission ([AndroidManifest.md](AndroidManifest.md#5-intent-filters-and-androidexported)).
+ Test from the shell:

```shell
adb shell am start -n com.example.app/.DetailActivity --ei com.example.pwm.extra.DUTY_PERCENT 50
adb shell am start -a android.intent.action.VIEW -d https://developer.android.com
adb shell am broadcast -a com.example.pwm.action.DUTY_CHANGED -p com.example.client
```

More `am` commands: [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md#1-am-activities-services-broadcasts).

## Related notes

+ [app_components.md](app_components.md): the four components and how intents connect them
+ [AndroidManifest.md](AndroidManifest.md): intent filters, `android:exported`, `<queries>`
+ [app_permissions.md](app_permissions.md): requesting and enforcing permissions
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): bound AIDL services
+ [../Signing/signature_permission.md](../Signing/signature_permission.md): who may bind, caller checks
+ [../HW/pwm_control.md](../HW/pwm_control.md): the PWM service used as the example
+ [boot_completed_receiver.md](boot_completed_receiver.md), [app_background_limits.md](app_background_limits.md)
+ [mediaPlayer_note.md](mediaPlayer_note.md): passing media to a player

## Reference

+ [Intents and intent filters](https://developer.android.com/guide/components/intents-filters)
+ [Common intents](https://developer.android.com/guide/components/intents-common)
+ [Bound services overview](https://developer.android.com/develop/background-work/services/bound-services)
+ [Broadcasts overview](https://developer.android.com/develop/background-work/background-tasks/broadcasts)
+ [Package visibility](https://developer.android.com/training/package-visibility)
+ [Behavior changes: apps targeting Android 14](https://developer.android.com/about/versions/14/behavior-changes-14)
+ [PendingIntent (Android API)](https://developer.android.com/reference/android/app/PendingIntent)
