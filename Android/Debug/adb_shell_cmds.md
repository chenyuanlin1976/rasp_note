# Device-side shell commands (`adb shell ...`)

These tools run **on the device**, either from `adb shell` or as `adb shell <cmd>`.
Connecting, installing, and file transfer are in [adb_intro.md](adb_intro.md).

Most framework tools are thin clients of a system service:

| Tool | Talks to | Use |
| --- | --- | --- |
| `am` | `activity` service | Start activities and services, send broadcasts, stop apps |
| `pm` | `package` service | List packages, permissions, paths |
| `cmd <service> ...` | Any service that implements a shell command | Generic front end (Android 7+). `am` ≈ `cmd activity`, `pm` ≈ `cmd package` |
| `dumpsys <service>` | Any service's `dump()` | Print state; a few services also accept commands (`battery`) |
| `settings` | SettingsProvider | Read and write `system` / `secure` / `global` settings |
| `svc` | Wi-Fi, connectivity, Bluetooth, USB, and power services | Toggle Wi-Fi, data, Bluetooth, USB functions, stay-awake; reboot, shut down |
| `getprop` / `setprop` | Property service | System properties |
| `wm`, `input` | Window manager, input manager | Screen size and density; inject keys and touches |

Each tool prints its usage with `-h` or `help`, for example `adb shell cmd package help`.
The output is the authoritative list for that Android version.

## 1. `am`: activities, services, broadcasts

Intent options are shared by `start`, `start-service`, and `broadcast`:

| Option | Meaning | Example |
| --- | --- | --- |
| `-a` | Action | `android.intent.action.VIEW` |
| `-c` | Category | `android.intent.category.HOME` |
| `-d` | Data URI | `https://example.com`, `tel:123` |
| `-t` | MIME type | `'image/*'` (quote it on the host) |
| `-n` | Component | `com.example.app/.MainActivity` |
| `-p` | Package (limits the Intent to one app) | `com.example.app` |
| `--es` / `--ei` / `--el` / `--ef` / `--ez` | String / int / long / float / boolean extra | `--es key value` |

```shell
adb shell am start -n com.example.app/.MainActivity
adb shell am start -W -n com.example.app/.MainActivity          # wait, print launch timing
adb shell am start -a android.intent.action.VIEW -d https://developer.android.com
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME   # go home
adb shell am start -a android.intent.action.VIEW -t 'image/*'   # pick an image viewer
adb shell am start -a android.intent.action.VIEW -t video/mp4 \
    -d file:///sdcard/Movies/demo.mp4 -n android.rk.RockVideoPlayer/.VideoPlayActivity
adb shell am start -a android.intent.action.SENDTO -d sms:+886912345678 --es sms_body "Test"

adb shell am force-stop com.example.app
adb shell am start-service -n com.example.app/.MyService
adb shell am start-foreground-service -n com.example.app/.MyService   # Android 8+ background limits
adb shell am stop-service -n com.example.app/.MyService

adb shell am broadcast -a com.example.app.ACTION_TEST -p com.example.app --es msg hello
```

Since Android 8, **implicit** broadcasts don't reach receivers declared in the manifest (except a few system broadcasts).
Add `-p <package>` or `-n <package>/<receiver>` to make the broadcast explicit.

System broadcasts such as `android.intent.action.BOOT_COMPLETED` are **protected**: only the system can send them.
`am broadcast -a android.intent.action.BOOT_COMPLETED` from the `shell` user fails with a `SecurityException`, unless adbd runs as root (`adb root`, section 7).
To test your own boot receiver, reboot, or send the broadcast as root with `-n <package>/<receiver>`.

## 2. `pm`: packages and permissions

```shell
adb shell pm list packages               # all
adb shell pm list packages -3            # third-party only   (-s: system only)
adb shell pm list packages -f            # with APK path      (-d / -e: disabled / enabled; -u: include uninstalled)
adb shell pm list packages webview       # filter by substring
adb shell pm path com.example.app        # APK path(s)
adb shell pm dump com.example.app | grep -E 'versionName|codePath'

adb shell pm grant  com.example.app android.permission.CAMERA      # runtime permissions only
adb shell pm revoke com.example.app android.permission.CAMERA
adb shell pm reset-permissions           # all apps: runtime permissions back to defaults
adb shell pm list permissions -g -d      # dangerous permissions, grouped
adb shell pm list features

adb shell pm disable-user --user 0 com.example.app   # hide/disable without uninstalling
adb shell pm enable com.example.app
```

## 3. `cmd`: generic service commands

`cmd <service> <args>` sends a shell command over Binder to a service registered with `servicemanager`.
Only services that implement a shell command respond to it.

```shell
adb shell cmd -l                          # services that can be addressed
adb shell cmd package list packages -3    # same as pm
adb shell cmd activity force-stop com.example.app
adb shell cmd <service> help              # usage for one service

# Which activity handles an Intent (here: all launcher entries)
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER
adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER

adb shell cmd statusbar expand-notifications   # also: expand-settings, collapse

# Doze testing: the device must look unplugged first
adb shell dumpsys battery unplug
adb shell cmd deviceidle force-idle       # enter deep Doze now
adb shell cmd deviceidle unforce
adb shell dumpsys battery reset
```

`svc` (section 6) is narrower: it only toggles Wi-Fi, data, Bluetooth, NFC, USB, and power.

## 4. `settings`

```shell
adb shell settings list global            # also: system, secure
adb shell settings get system screen_brightness
adb shell settings put system screen_brightness 120
adb shell settings get secure android_id
adb shell settings put global stay_on_while_plugged_in 7     # AC|USB|wireless: keep screen on while charging

# Animation scales (Developer options); 0 disables animations, useful for UI tests
adb shell settings get global window_animation_scale
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Battery Saver: 1 = on, 0 = off (a device that is charging won't enter it, so simulate unplugging)
adb shell dumpsys battery unplug
adb shell settings put global low_power 1
adb shell dumpsys battery reset
```

How the 3 namespaces are stored and protected: [../AOSP_cfg/SettingsProvider_intro.md](../AOSP_cfg/SettingsProvider_intro.md).

## 5. `dumpsys`

`dumpsys <service>` calls the `dump()` method of a Binder service and prints the result to stdout (not to logcat).
Without a service name, it dumps every service, which is long and slow. Always name one.

| Service | Shows |
| --- | --- |
| `battery` | AC/USB powered, status, health, level, voltage (mV), temperature (0.1 °C) |
| `meminfo [<pkg>\|<pid>]` | Per-process PSS summary, or one app's Java heap, native heap, graphics memory |
| `cpuinfo` | Recent CPU load per process |
| `power` | Screen state, wake locks (what keeps the CPU awake), stay-on and Battery Saver state |
| `deviceidle` | Doze state and the idle allowlist |
| `activity` | Activities, services, broadcasts, processes (`activity top`: view hierarchy of the top activity) |
| `window` | Windows, focus, display size |
| `package <pkg>` | Version, paths, permissions, components of one package |
| `wifi`, `connectivity` | Wi-Fi state and networks, default network |
| `sensorservice` | Sensors, active connections, recent events |
| `SurfaceFlinger` | Layers and displays |

```shell
adb shell dumpsys -l                      # list services (same names as "service list")
adb shell dumpsys activity -h             # per-service help, where supported
adb shell dumpsys package com.example.app # one package
adb shell dumpsys activity activities | grep ResumedActivity            # foreground activity
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'                        # focused window
adb shell dumpsys meminfo com.example.app
adb shell dumpsys power | grep -A 20 'Wake Locks'   # who blocks suspend
adb shell dumpsys SurfaceFlinger --display-id
```

`dumpsys battery` also changes the **reported** battery state, which is useful for testing:

```shell
adb shell dumpsys battery set level 15    # 0-100
adb shell dumpsys battery set status 3    # 1 unknown, 2 charging, 3 discharging, 4 not charging, 5 full
adb shell dumpsys battery set usb 0       # 0/1; also: ac, wireless
adb shell dumpsys battery unplug
adb shell dumpsys battery reset           # back to the real values
```

## 6. `svc`

`svc` asks the framework services (Wi-Fi, connectivity, Bluetooth, USB, power manager) to change state, the same way the Settings UI does.
It is handy in test scripts, and on boards without a usable UI.

```shell
adb shell svc wifi enable                 # disable
adb shell svc data enable                 # disable (mobile data; needs a modem)
adb shell svc bluetooth enable            # disable
adb shell svc usb getFunctions
adb shell svc usb setFunctions mtp        # mtp, ptp, rndis, midi, ... (empty: charging only)
adb shell svc power stayon usb            # true | false | usb | ac | wireless
adb shell svc power reboot
adb shell svc power shutdown              # powers the device off (not screen off / sleep)
```

+ Run `adb shell svc` to see the subcommands that this release supports.
+ `svc power shutdown` powers off through the full framework path; see [../AOSP_cfg/shutdown_flow.md](../AOSP_cfg/shutdown_flow.md).
  To turn only the screen off, use `input keyevent KEYCODE_SLEEP` (section 8).
+ `svc power stayon` writes the `stay_on_while_plugged_in` global setting (section 4).
+ `setFunctions` doesn't control adb. adb follows the `adb_enabled` global setting (Developer options → USB debugging).
  Changing the USB functions briefly re-enumerates the port, so the adb connection may drop and come back.

Check that a change took effect:

```shell
adb shell dumpsys wifi | grep 'Wi-Fi is'                  # Wi-Fi is enabled / disabled
adb shell settings get global stay_on_while_plugged_in    # 0 off, 1 AC, 2 USB, 4 wireless (bitmask)
adb shell svc usb getFunctions
```

## 7. Properties

```shell
adb shell getprop                         # everything
adb shell getprop ro.build.version.release   # e.g. 14
adb shell getprop ro.build.version.sdk       # e.g. 34
adb shell getprop ro.build.type              # user / userdebug / eng
adb shell getprop ro.product.cpu.abilist
adb shell getprop | grep -iE 'board|hardware|rk35'   # SoC and board properties
adb shell setprop log.tag.MyApp D            # allowed for shell; most other properties are restricted by SELinux
```

`setprop <name> <value>` asks init's property service to change a property. Rules:

| Prefix | Behavior |
| --- | --- |
| `ro.*` | Set once (from `build.prop` files or init, at boot). Any later `setprop` fails |
| `persist.*` | Survives a reboot; init saves it to `/data/property/persistent_properties` |
| `ctl.*` | Not a value: `ctl.start` / `ctl.stop` / `ctl.restart` tell init to control a service (root only) |
| others | Runtime only; lost at reboot |

+ Who may set a property is decided by SELinux: `property_contexts` gives each property a type, and the caller's domain needs `set_prop` on it.
  The `shell` domain can set only a few types (`log.tag.*`, some `debug.*`); for the rest, `setprop` fails silently or logs `avc: denied`.
+ `adb root` restarts adbd as root (domain `su`) and works only on `userdebug` and `eng` builds (`ro.debuggable=1`).
  On a `user` build it prints `adbd cannot run as root in production builds`.
+ Prefer the framework commands over writing properties directly.
  For example, use `svc usb setFunctions mtp` (section 6) instead of `setprop persist.sys.usb.config mtp,adb`: on recent releases the USB HAL and `UsbDeviceManager` own that property.
+ Network MAC addresses are not properties. Use `adb shell ip link` or `adb shell cat /sys/class/net/eth0/address`.

## 8. Screen and input

```shell
adb shell wm size                         # physical and override resolution
adb shell wm size 1920x1080               # override; "wm size reset" to undo
adb shell wm density                      # "wm density 240" / "wm density reset"

adb shell input text 'hello%sworld'       # %s = space
adb shell input keyevent KEYCODE_HOME     # names or numbers, e.g. 3
adb shell input tap 500 800
adb shell input swipe 500 1500 500 300 300   # x1 y1 x2 y2 duration_ms
```

| Key | Code | Key | Code |
| --- | --- | --- | --- |
| `KEYCODE_HOME` | 3 | `KEYCODE_ENTER` | 66 |
| `KEYCODE_BACK` | 4 | `KEYCODE_DEL` (backspace) | 67 |
| `KEYCODE_CALL` / `KEYCODE_ENDCALL` | 5 / 6 | `KEYCODE_MENU` | 82 |
| `KEYCODE_POWER` (toggle screen on/off) | 26 | `KEYCODE_BRIGHTNESS_DOWN` / `_UP` | 220 / 221 |
| `KEYCODE_CAMERA` | 27 | `KEYCODE_WAKEUP` / `KEYCODE_SLEEP` | 224 / 223 |
| `KEYCODE_EXPLORER` (browser) | 64 | `KEYCODE_CUT` / `COPY` / `PASTE` | 277 / 278 / 279 |

## 9. Processes and memory

```shell
adb shell ps -A                           # all processes (toybox ps, Android 8+)
adb shell ps -AZ                          # with SELinux context
adb shell pidof com.example.app
adb shell top -m 10
adb shell cat /proc/meminfo
adb shell dumpsys meminfo                 # per-process PSS summary; "dumpsys meminfo <pkg>" for one app
adb shell procrank                        # userdebug/eng only (if built)
adb logcat -d | grep -i lowmemorykiller   # processes killed by lmkd
adb shell service list                    # registered Binder services
```

## 10. Stress test with monkey

```shell
# Options first; the event count is the LAST argument
adb shell monkey -p com.example.app -s 100 --throttle 100 -v 10000
```

`-s` is the random seed (the same seed replays the same sequence). `-v` raises verbosity.

## 11. Useful paths

| Path | Content |
| --- | --- |
| `/data/data/<pkg>` (= `/data/user/0/<pkg>`) | App private data: `databases/`, `shared_prefs/`, `files/` (root or `run-as <pkg>` for debuggable apps) |
| `/data/app/` | APKs installed by users (one random-named directory per app) |
| `/system/app`, `/system/priv-app`, `/product/app`, `/vendor/app` | Preinstalled APKs |
| `/sdcard` = `/storage/emulated/0` | Shared storage |
| `/data/local/tmp` | Scratch directory for the `shell` user |
| `/data/tombstones`, `/data/anr` | Native crash dumps, ANR traces (root; included in `adb bugreport`) |

```shell
adb shell run-as com.example.app ls shared_prefs     # debuggable app, no root needed
```

## 12. Hardware state from sysfs and debugfs (RK3566)

debugfs (`/sys/kernel/debug`) is not available on user builds. On userdebug builds, use `adb root` first.

```shell
adb shell 'for d in /sys/bus/iio/devices/iio:device*; do echo "$d $(cat $d/name)"; done'
adb shell 'cat /sys/bus/iio/devices/iio:device0/in_voltage*_raw'   # SAR-ADC raw values
adb shell cat /sys/kernel/debug/pwm                    # PWM channels: period, duty, polarity, enabled
adb shell cat /sys/kernel/debug/gpio                   # which GPIO lines are claimed, and by whom
adb shell cat /sys/kernel/debug/regulator/regulator_summary
adb shell cat /sys/kernel/debug/clk/clk_summary
```

Converting ADC values: [../HW/ADC_values.md](../HW/ADC_values.md). GPIO ownership: [../HW/gpio_control.md](../HW/gpio_control.md).

## Related notes

+ [adb_intro.md](adb_intro.md), [logcat_intro.md](logcat_intro.md)
+ [../AOSP_cfg/shutdown_flow.md](../AOSP_cfg/shutdown_flow.md): what happens after `svc power shutdown` or `reboot -p`
+ [../AOSP_cfg/SettingsProvider_intro.md](../AOSP_cfg/SettingsProvider_intro.md), [../HW/ADC_values.md](../HW/ADC_values.md), [../HW/gpio_control.md](../HW/gpio_control.md)

## Reference

+ [adb: shell commands, `am`, `pm`, screencap, screenrecord](https://developer.android.com/tools/adb)
+ [dumpsys](https://developer.android.com/tools/dumpsys)
+ [UI/Application Exerciser Monkey](https://developer.android.com/studio/test/other-testing-tools/monkey)
+ [KeyEvent key codes](https://developer.android.com/reference/android/view/KeyEvent)
+ [Firefly ROC-RK3566-PC wiki](https://wiki.t-firefly.com/en/ROC-RK3566-PC/index.html)
