# App stopped state and background limits

This note collects the rules that decide when an app's code may run without the user opening it: the stopped state after install, background service limits, wake locks, `android:persistent`, and starting an activity from the background.
Most of these rules are stricter on every new Android release, so check the behavior-change pages for your `targetSdk`.

## 1. The stopped state

Since Android 3.1, an app is in the **stopped state** right after it's installed, and again after the user taps **Force stop** in Settings.
While stopped:

+ It receives **no broadcasts**, including `BOOT_COMPLETED`, because the system adds `FLAG_EXCLUDE_STOPPED_PACKAGES` to broadcasts by default.
+ Its alarms and scheduled jobs don't run, and its services aren't started by the system.

The app leaves the stopped state when something explicitly starts one of its components: the user opens it from the launcher, another app sends an explicit intent to it, or you start it with `adb`:

```shell
adb shell am start -n com.example.app/.MainActivity          # start an activity
adb shell am start-foreground-service -n com.example.app/.MyService
adb shell dumpsys package com.example.app | grep stopped     # stopped=true/false per user
```

### 1.1 "Start a service when the APK is installed"

A normal app can't do this. There is no install broadcast to the app itself, and it can't receive anything until it leaves the stopped state.
The usual design is: the user opens the app once, and from then on it can use `BOOT_COMPLETED` (with `RECEIVE_BOOT_COMPLETED`) or WorkManager.

Apps preinstalled in the system image are installed without the stopped state at first boot, so they receive `BOOT_COMPLETED` without being opened.
This is the right solution on your own device build; see [AOSP_preinstalled_apps.md](AOSP_preinstalled_apps.md).
For quick tests on a `userdebug` build, you can also push the APK into `/system/app/<Name>/<Name>.apk` (or `/product/app/...`) after `adb root` and `adb remount`, then reboot.

A preinstalled app can still be **updated** like a normal app if the update has the same package name and is signed with the same key.
The update is installed in `/data/app` and the app keeps its system status; "Uninstall updates" returns to the version in the image.

## 2. Background services (Android 8+)

| Release | Rule |
| --- | --- |
| Android 8 (API 26) | An app in the background can't call `startService()` (it throws `IllegalStateException`). Use `startForegroundService()` and call `startForeground()` within a few seconds, or use WorkManager / JobScheduler |
| Android 12 (API 31) | Apps targeting 12+ can't start a foreground service from the background, except for listed exemptions (e.g. a high-priority FCM message, exact alarm, user interaction with a notification) |
| Android 14 (API 34) | Every foreground service must declare `android:foregroundServiceType` in the manifest and hold the matching `FOREGROUND_SERVICE_<TYPE>` permission |

A **bound** service runs as long as a client is bound to it, and isn't affected by these start rules; see [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md).
For deferrable work (sync, upload, cleanup), use **WorkManager** instead of a long-running service.

## 3. Wake locks

A partial wake lock keeps the CPU running while the screen is off. It drains the battery, so use it only when nothing else fits, and release it as soon as possible.

```kotlin
val pm = getSystemService(PowerManager::class.java)
val wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MyApp:sync")
wakeLock.acquire(10 * 60 * 1000L)      // always with a timeout
try {
    doWork()
} finally {
    wakeLock.release()
}
```

+ Needs the `android.permission.WAKE_LOCK` permission (normal, granted at install).
+ To keep the **screen** on while an activity is visible, don't use a wake lock: set `android:keepScreenOn="true"` on a view or `FLAG_KEEP_SCREEN_ON` on the window.
+ WorkManager and foreground services already hold the wake locks they need.

## 4. `android:persistent`

```xml
<application android:persistent="true" ... >
```

This keeps the app's process running at all times and restarts it if it dies.
It is honored **only for system apps** (in the system image); a normal app's setting is ignored.
Use it only for core components that must always run (e.g. the phone process). It costs memory for the life of the device.

## 5. Starting an activity from the background

Since **Android 10** (API 29), an app in the background can't start an activity whenever it likes.
`FLAG_ACTIVITY_NEW_TASK` is still required when starting an activity from a non-activity `Context` (a service), but the flag doesn't bypass the restriction.

```kotlin
val intent = Intent(this, TargetActivity::class.java)
    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
startActivity(intent)        // works only if one of the exemptions below applies
```

The start is allowed when, for example:

+ The app has a visible window, or an activity in the foreground task.
+ The app's own activity was started or finished a few seconds ago (grace period).
+ The start comes from a `PendingIntent` that the user triggers from a notification.
+ The app holds `SYSTEM_ALERT_WINDOW`, or is a device policy controller or an associated companion app.
+ A visible app that binds to the service passes `Context.BIND_ALLOW_ACTIVITY_STARTS`.

Running a foreground service does **not**, by itself, allow background activity starts.

Android 14 made the rules stricter. An app that sends a `PendingIntent` must opt in before the target may start activities with the sender's privileges (`ActivityOptions.setPendingIntentBackgroundActivityStartMode()`).
Full-screen intent notifications (`USE_FULL_SCREEN_INTENT`) are limited to calling and alarm apps on new installs.

**What to do instead:** post a notification with a `PendingIntent` and let the user tap it.
For a call or alarm, use a high-priority notification with a full-screen intent.

## 6. Comments

+ **Design for being stopped.** A newly installed app runs nothing until the user opens it. If your product needs code running from first boot, it should be a preinstalled system app, not a downloaded one.
+ **Pick the lightest mechanism.** WorkManager for deferrable work, a foreground service for user-visible ongoing work, a bound service for client/server calls. A wake lock or `persistent` is the last resort.
+ **Test with the real restrictions.** Force-stop the app (`adb shell am force-stop <pkg>`) and check that it behaves as expected. Background limits often don't show up while you're debugging with the app in the foreground.
+ **Check each release.** Android 15 changed the stopped state again (for example, pending intents and alarms are cleared when an app is force-stopped). Read the behavior changes for every new `targetSdk`.

## Related notes

+ [AOSP_preinstalled_apps.md](AOSP_preinstalled_apps.md): system apps, `priv-app`, factory reset behavior
+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md): bound services and foreground services
+ [AndroidManifest.md](AndroidManifest.md): declaring services, receivers and permissions
+ [sharedUserId.md](sharedUserId.md): shared UIDs for platform apps
+ [android_class_hierarchy.md](android_class_hierarchy.md): why `this` is a `Context` in an `Activity` or `Service`
+ [android_studio_ide.md](android_studio_ide.md): Android Studio icons and build variants

## Reference

+ [Background execution limits (Android 8)](https://developer.android.com/about/versions/oreo/background)
+ [Restrictions on starting activities from the background](https://developer.android.com/guide/components/activities/background-starts)
+ [Foreground services](https://developer.android.com/develop/background-work/services/fgs)
+ [Keep the device awake / wake locks](https://developer.android.com/develop/background-work/background-tasks/awake/wakelock)
+ [WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent)
+ [`<application>` element (android:persistent)](https://developer.android.com/guide/topics/manifest/application-element)
