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
| `svc` | Connectivity, power, and USB services | Toggle Wi-Fi, data, USB functions, stay-awake |
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
```

`svc` (section 6) is narrower: it only toggles Wi-Fi, data, Bluetooth, NFC, USB, and power.

## 4. `settings`

```shell
adb shell settings list global            # also: system, secure
adb shell settings get system screen_brightness
adb shell settings put system screen_brightness 120
adb shell settings get secure android_id
adb shell settings put global stay_on_while_plugged_in 7     # AC|USB|wireless: keep screen on while charging

# Battery Saver: 1 = on, 0 = off (a device that is charging won't enter it, so simulate unplugging)
adb shell dumpsys battery unplug
adb shell settings put global low_power 1
adb shell dumpsys battery reset
```

How the 3 namespaces are stored and protected: [SettingsProvider_intro.md](SettingsProvider_intro.md).

## 5. `dumpsys`

```shell
adb shell dumpsys -l                      # list services (same names as "service list")
adb shell dumpsys activity -h             # per-service help, where supported
adb shell dumpsys package com.example.app # one package
adb shell dumpsys activity activities | grep ResumedActivity            # foreground activity
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'                        # focused window
adb shell dumpsys meminfo com.example.app
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

```shell
adb shell svc wifi enable                 # disable
adb shell svc data enable                 # disable (mobile data)
adb shell svc bluetooth enable            # disable
adb shell svc usb getFunctions
adb shell svc usb setFunctions mtp        # mtp, ptp, rndis, midi, ... (empty: charging only)
adb shell svc power stayon usb            # true | false | usb | ac | wireless
adb shell svc power reboot
adb shell svc power shutdown
```

Run `adb shell svc` to see the subcommands that this release supports.
`svc` is handy in test scripts, and on boards without a usable UI.

## 7. Properties

```shell
adb shell getprop                         # everything
adb shell getprop ro.build.version.release   # e.g. 14
adb shell getprop ro.build.version.sdk       # e.g. 34
adb shell getprop ro.build.type              # user / userdebug / eng
adb shell getprop ro.product.cpu.abilist
adb shell getprop | grep -i hardware
adb shell setprop log.tag.MyApp D            # allowed for shell; most other properties are restricted by SELinux
```

+ `ro.*` properties are read-only after boot. `persist.*` properties survive a reboot.
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

Converting ADC values: [ADC_values.md](ADC_values.md). GPIO ownership: [gpio_control.md](gpio_control.md).

## Related notes

+ [adb_intro.md](adb_intro.md), [logcat_intro.md](logcat_intro.md)
+ [SettingsProvider_intro.md](SettingsProvider_intro.md), [ADC_values.md](ADC_values.md), [gpio_control.md](gpio_control.md)

## Reference

+ [adb: shell commands, `am`, `pm`, screencap, screenrecord](https://developer.android.com/tools/adb)
+ [dumpsys](https://developer.android.com/tools/dumpsys)
+ [UI/Application Exerciser Monkey](https://developer.android.com/studio/test/other-testing-tools/monkey)
+ [KeyEvent key codes](https://developer.android.com/reference/android/view/KeyEvent)
+ [Firefly ROC-RK3566-PC wiki](https://wiki.t-firefly.com/en/ROC-RK3566-PC/index.html)
