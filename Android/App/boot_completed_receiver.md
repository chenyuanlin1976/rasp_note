# Start app code at boot (BOOT_COMPLETED)

An app can run code after the device boots by registering a `BroadcastReceiver` for `ACTION_BOOT_COMPLETED`.
On Android 14 the receiver itself is easy; the hard part is what it is allowed to start afterwards (foreground services, activities) and whether it receives the broadcast at all (stopped state, OEM battery managers).
The general rules are in [app_background_limits.md](app_background_limits.md); this note covers the boot case.

## 1. Boot broadcasts

| Broadcast | When | Storage available |
| --- | --- | --- |
| `LOCKED_BOOT_COMPLETED` | After boot, before the user unlocks for the first time (Direct Boot, Android 7+) | Device-protected storage only |
| `BOOT_COMPLETED` | After the user unlocks for the first time | Credential-protected and device-protected storage |

Both need the `RECEIVE_BOOT_COMPLETED` permission.
`LOCKED_BOOT_COMPLETED` is delivered only to components marked `android:directBootAware="true"`.
Most apps only need `BOOT_COMPLETED`.

Both are exempt from the Android 8 limit on implicit broadcasts, so a receiver declared in the manifest still gets them.

## 2. Implementation

### 2.1 Manifest

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

<application ...>
    <receiver
        android:name=".BootCompletedReceiver"
        android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
        </intent-filter>
    </receiver>

    <service
        android:name=".MyForegroundService"
        android:exported="false"
        android:foregroundServiceType="specialUse">
        <property
            android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
            android:value="Explain why the service starts at boot" />
    </service>
</application>
```

+ `android:exported="false"` is enough: the system can deliver its own broadcasts to non-exported receivers, and nothing else can reach the receiver.
  `BOOT_COMPLETED` is a protected broadcast, so other apps can't send it anyway.
+ Since Android 12, a component with an `<intent-filter>` must set `android:exported` explicitly.
+ Since Android 14, every foreground service must declare a `foregroundServiceType` and hold the matching `FOREGROUND_SERVICE_<TYPE>` permission.
  Pick the type that matches the work (`specialUse` is the fallback when none fits, and Google Play reviews it).
+ For Direct Boot, add the `LOCKED_BOOT_COMPLETED` action and set `android:directBootAware="true"` on the receiver **and** on the service it starts.

### 2.2 Receiver

```kotlin
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.i("BootReceiver", "boot completed")

        val serviceIntent = Intent(context, MyForegroundService::class.java)
        context.startForegroundService(serviceIntent)
    }
}
```

+ `onReceive()` runs on the main thread and has about 10 seconds; don't do long work in it.
  Start a service, or enqueue a WorkManager job for deferrable work.
+ Starting a foreground service from `BOOT_COMPLETED` is one of the exemptions to the Android 12 "no foreground service from the background" rule.
+ The service must call `startForeground()` within a few seconds of `startForegroundService()`, or the system stops the app with an ANR.
+ Not every type may start from `BOOT_COMPLETED`: Android 14 blocks `microphone`, and apps targeting Android 15 also can't start `dataSync`, `camera`, `mediaPlayback`, `phoneCall` or `mediaProjection` services from it (`ForegroundServiceStartNotAllowedException`).
  Check the behavior-change page for your `targetSdk`.

### 2.3 Activities

A receiver can't simply open an activity at boot: since Android 10, background activity starts are blocked (see [app_background_limits.md](app_background_limits.md), section 5).
Options:

+ Post a notification with a `PendingIntent` and let the user tap it.
+ On your own device build (kiosk, panel), make the app the **HOME** app (`category.HOME` + `category.DEFAULT` on the activity), so the system launches it after every boot.
+ A privileged system app can hold `START_ACTIVITIES_FROM_BACKGROUND`.

## 3. User app vs. preinstalled system app

| Topic | User app (Play Store / sideloaded) | Preinstalled app (`/system/app`, `/system/priv-app`, `/product/app`) |
| --- | --- | --- |
| Stopped state | After install the app is stopped and gets **no** `BOOT_COMPLETED` until the user opens it once. Force stop puts it back in the stopped state | Not stopped at first boot, so it gets `BOOT_COMPLETED` without being opened. A user force stop still stops it |
| Background limits | Normal rules: foreground service with a valid type and notification; no background activity starts | Same rules by default; a privileged app can be granted extra permissions (e.g. `START_ACTIVITIES_FROM_BACKGROUND`) through `privapp-permissions` XML |
| Battery / OEM auto-start | OEM managers (e.g. Samsung, Xiaomi) may block auto-start until the user allows it or exempts the app from battery optimization | Usually exempt; in AOSP, add the package to the power-save allowlist (`<allow-in-power-save>` in a `sysconfig` XML) |

For building an app into the image, see [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md).

## 4. Testing

```shell
adb reboot
adb wait-for-device
adb logcat -s BootReceiver

# check the stopped state (stopped=true means no BOOT_COMPLETED)
adb shell dumpsys package com.example.app | grep stopped

# send the broadcast without rebooting (userdebug build, needs adb root)
adb root
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED -p com.example.app
```

A fake broadcast doesn't reproduce real boot timing, so confirm with a real reboot.

## 5. Comments

+ After an app update, the app is not stopped, but nothing restarts it either. Listen for `ACTION_MY_PACKAGE_REPLACED` if the service must come back after an update.
+ Prefer WorkManager when the work doesn't have to start immediately; it survives reboots by itself.

## Related notes

+ [app_background_limits.md](app_background_limits.md): stopped state, background services, activity starts
+ [app_components.md](app_components.md): services and broadcast receivers
+ [AndroidManifest.md](AndroidManifest.md): declaring receivers, services and permissions
+ [../AOSP_cfg/AOSP_preinstalled_apps.md](../AOSP_cfg/AOSP_preinstalled_apps.md): preinstalled and privileged apps

## Reference

+ [Broadcasts overview](https://developer.android.com/develop/background-work/background-tasks/broadcasts)
+ [Support Direct Boot mode](https://developer.android.com/privacy-and-security/direct-boot)
+ [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
+ [Restrictions on starting a foreground service from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
+ [Behavior changes: Android 15 (BOOT_COMPLETED and foreground services)](https://developer.android.com/about/versions/15/behavior-changes-15)
+ [Restrictions on starting activities from the background](https://developer.android.com/guide/components/activities/background-starts)
