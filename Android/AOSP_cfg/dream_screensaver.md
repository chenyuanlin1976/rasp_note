# Dreams (screensaver), DreamManagerService, and Doze

A **dream** is Android's screensaver (called "Daydream" in Android 4.2 to 6.0). It is an app's `DreamService` that the system shows instead of turning the screen off,
typically while the device is charging or docked: a bedside clock, a photo frame, ambient art.
**`DreamManagerService`** (`frameworks/base/services/core/java/com/android/server/dreams/`, binder name `dreams`) is the system service that starts and stops dreams.

Two unrelated features are both called "doze", so keep them apart:

| Term | What it is | Owner |
| --- | --- | --- |
| **Dream** (screensaver) | A `DreamService` drawn on screen while idle and powered | `DreamManagerService`, triggered by `PowerManagerService` |
| **Doze dream** (ambient display, always-on display) | A special dream (`config_dozeComponent`, SystemUI's `DozeService`) that runs while the device is "asleep", with the display in a low-power state | `DreamManagerService` + `PowerManagerService` |
| **Doze mode** (device idle) | Battery optimization that restricts apps' network, jobs, alarms, and wakelocks while the screen is off and the device is unplugged | `DeviceIdleController` |

## 1. When a dream starts

`PowerManagerService` (PMS) tracks a "wakefulness" state. Simplified:

```text
AWAKE ──(screen timeout)──► dreams enabled and conditions met? ──yes──► DREAMING  (screensaver dream)
  ▲                                     │ no                                 │ dream ends without user input
  │                                     ▼                                    ▼
  │                                 go to sleep ◄───────────────────────────┘
  │                                     │
  │                                     ▼
  │                         DOZING  (doze dream / AOD, if config_dozeComponent is set)
  │                                     │ doze dream ends or isn't configured
  │                                     ▼
  └────────(user input, power key)── ASLEEP  (display off)
```

The conditions come from the user's "When to start" choice (Settings > Display > Screen saver):

| Choice | `Settings.Secure` keys |
| --- | --- |
| While charging | `screensaver_activate_on_sleep=1` |
| While docked | `screensaver_activate_on_dock=1` (the dock event starts it, via `UiModeManagerService`) |
| Never | `screensaver_enabled=0` |

Framework configs can block dreams on battery or at low battery level
(`config_dreamsEnabledOnBattery`, `config_dreamsBatteryLevelMinimumWhenPowered`, `config_dreamsBatteryLevelMinimumWhenNotPowered`).

A dream stops when the user touches the screen or presses a key (unless it is interactive), when something wakes the device (incoming call, power key),
or when its start condition goes away (for example, unplugging while "While charging" is selected).

## 2. What DreamManagerService does

+ **Selection**: keeps the chosen dream component (`screensaver_components`) and the default one (`config_dreamsDefaultComponent`).
+ **Lifecycle**: binds to the app's `DreamService`, gives it a window, and unbinds when the dream stops.
+ **Doze dream**: starts the doze component when PMS enters `DOZING`. The doze dream asks for the low-power display states (`Display.STATE_DOZE`, `STATE_DOZE_SUSPEND`).
+ **Power coordination**: PMS decides when to dream or sleep. DreamManagerService tells PMS when a dream finishes, and PMS then goes to sleep.

## 3. Writing a dream (app side)

```kotlin
class ClockDream : DreamService() {
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = false          // any touch ends the dream
        isFullscreen = true
        setContentView(R.layout.clock_dream)
    }

    override fun onDreamingStarted() { /* start animations */ }
    override fun onDreamingStopped() { /* stop animations */ }
}
```

```xml
<service
    android:name=".ClockDream"
    android:exported="true"
    android:label="@string/dream_label"
    android:permission="android.permission.BIND_DREAM_SERVICE">
    <intent-filter>
        <action android:name="android.service.dreams.DreamService" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
    <meta-data
        android:name="android.service.dream"
        android:resource="@xml/clock_dream" />   <!-- <dream android:settingsActivity="..."/> -->
</service>
```

`BIND_DREAM_SERVICE` makes sure that only the system can bind to it. The dream then appears in the Screen saver list in Settings.

## 4. Defaults in an AOSP build

The first-boot values come from framework configs in `frameworks/base/core/res/res/values/config.xml`.
SettingsProvider copies them into the `Settings.Secure` keys above on first boot.
Override them in a device overlay (`device/<vendor>/<board>/overlay/frameworks/base/core/res/res/values/config.xml`) instead of editing the framework:

```xml
<resources>
    <bool name="config_dreamsSupported">true</bool>
    <bool name="config_dreamsEnabledByDefault">true</bool>
    <bool name="config_dreamsActivatedOnSleepByDefault">true</bool>   <!-- while charging -->
    <bool name="config_dreamsActivatedOnDockByDefault">true</bool>
    <string name="config_dreamsDefaultComponent" translatable="false">com.example.clock/.ClockDream</string>
</resources>
```

Like other first-boot defaults, they apply only after a factory reset or a fresh flash. See [SettingsProvider_intro.md](SettingsProvider_intro.md#3-default-values-in-an-aosp-build).
To preinstall the dream app, see [AOSP_preinstalled_apps.md](AOSP_preinstalled_apps.md).

## 5. Doze mode (device idle)

Doze mode (Android 6.0+) is not a dream and doesn't show anything. `DeviceIdleController` enters it in stages:

+ **Light doze** (Android 7.0+): screen off and unplugged for a while.
+ **Deep doze**: screen off, unplugged, **and stationary** for a longer time (motion sensors).

While dozing, apps lose network access, their wakelocks are ignored, and jobs, syncs, and standard alarms are deferred to short maintenance windows.
`setAndAllowWhileIdle()`, `setExactAndAllowWhileIdle()`, and `setAlarmClock()` still fire.

Doze mode and screensaver dreams rarely overlap: a screensaver usually runs while the device is charging, and Doze mode needs the device unplugged.

## 6. Commands

```shell
adb shell dumpsys dreams                                  # DreamManagerService state, current dream
adb shell dumpsys power | grep -i -E "wakefulness|dream"  # PMS state: Awake / Dreaming / Dozing / Asleep

adb shell settings get secure screensaver_enabled
adb shell settings put secure screensaver_enabled 1
adb shell settings put secure screensaver_activate_on_sleep 1
adb shell settings put secure screensaver_components com.example.clock/.ClockDream

# Doze mode testing (developer.android.com "Test with Doze")
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle force-idle
adb shell dumpsys deviceidle unforce
adb shell dumpsys battery reset
```

## Related notes

+ [SettingsProvider_intro.md](SettingsProvider_intro.md), [AOSP_preinstalled_apps.md](AOSP_preinstalled_apps.md)
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md), [../HW/Led_control.md](../HW/Led_control.md) (Doze vs. kernel LED triggers)

## Reference

+ [`DreamService`](https://developer.android.com/reference/android/service/dreams/DreamService)
+ [Optimize for Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
+ [`PowerManager`](https://developer.android.com/reference/android/os/PowerManager)
