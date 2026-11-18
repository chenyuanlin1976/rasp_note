# adb (Android Debug Bridge)

`adb` is a client/server tool for talking to Android devices from a host computer:

```text
host                                         device
adb client  --->  adb server (port 5037)  --USB/TCP-->  adbd (daemon)
(each command)    (started on first use)
```

This note covers the host side: installing adb, connecting, files, apps, and reboot modes.
Commands that run **on** the device (`am`, `pm`, `cmd`, `settings`, `dumpsys`, ...) are in [adb_shell_cmds.md](adb_shell_cmds.md).
Logs are in [logcat_intro.md](logcat_intro.md).

## 1. Install adb on the host

| Host | How |
| --- | --- |
| Linux / macOS / Windows x86-64 | Google's **SDK Platform-Tools** (`adb`, `fastboot`), from the Android Studio SDK Manager or as a standalone zip |
| Debian / Ubuntu (any arch) | `sudo apt install adb fastboot` (distribution build, often older than Platform-Tools) |
| Linux arm64 (Raspberry Pi, Orange Pi, Jetson) | Google ships no Linux arm64 Platform-Tools, so use the distribution package. Unofficial builds exist, for example [lzhiyong/android-sdk-tools](https://github.com/lzhiyong/android-sdk-tools/releases) |

+ On Linux, a non-root user needs a udev rule for the device's USB vendor ID.
  The `android-sdk-platform-tools-common` package on Debian/Ubuntu installs common rules. Also add the user to the `plugdev` group.
+ Android Studio itself is not officially supported on Linux arm64.

## 2. Connect a device

### 2.1 USB

Enable **Developer options → USB debugging** on the device, plug it in, and accept the RSA key prompt.

```shell
adb devices          # "unauthorized": accept the prompt on the device (no screen: §2.2); "no permissions": udev rule missing
adb devices -l       # also show product, model, transport_id
```

### 2.2 "unauthorized" on a board without a screen

adbd accepts a host only if the host's public key is listed in `/data/misc/adb/adb_keys`.
Normally the key gets there when someone taps "Allow" on the RSA prompt.
On a headless board (no display or touch), write the key by hand from the [serial console](uart_console.md).
This needs root on the console, so a userdebug or eng build.

1. **Host**: find the key pair in `~/.android/` (Windows: `%USERPROFILE%\.android\`).
   If `adbkey.pub` doesn't exist, run any adb command (for example `adb devices`); the server creates `adbkey` and `adbkey.pub` when it starts.
   Copy the one line in `adbkey.pub`.
2. **Device**, on the UART console:

   ```shell
   su
   mkdir -p /data/misc/adb
   echo "QAAAA...= user@host" >> /data/misc/adb/adb_keys   # the line from adbkey.pub; >> keeps other hosts' keys
   chown system:shell /data/misc/adb/adb_keys
   chmod 640 /data/misc/adb/adb_keys
   restorecon /data/misc/adb/adb_keys                        # SELinux label adb_keys_file
   ls -lZ /data/misc/adb/adb_keys
   ```

3. **Restart and check**: `stop adbd && start adbd` on the device, `adb kill-server` on the host, re-plug USB, then `adb devices`.
   The state should change from `unauthorized` to `device`.

Alternatives for development builds:

+ Set `PRODUCT_ADB_KEYS` in the product makefile to the path of an `adbkey.pub`; the build puts the key into the image, so every flashed board trusts that host.
+ `ro.adb.secure=0` in the build properties turns off key authentication completely. Never ship a user build like that.

### 2.3 Over the network

```shell
# Android 11+: Developer options -> Wireless debugging -> Pair device with pairing code
adb pair 192.168.1.50:37123          # port and code shown on the device
adb connect 192.168.1.50:41235       # the "IP address & Port" shown on the Wireless debugging screen

# Any version: switch adbd to TCP while connected over USB
adb tcpip 5555
adb connect 192.168.1.50:5555
adb disconnect 192.168.1.50:5555
adb usb                              # back to USB mode
```

On a development board (userdebug, no USB OTG), adbd can be put on TCP from the [serial console](uart_console.md).
The console shell runs as user `shell`, so switch to root first:

```shell
su
setprop service.adb.tcp.port 5555
stop adbd && start adbd
```

### 2.4 Choose a device

When more than one device is connected, every command needs a target:

| Option | Target |
| --- | --- |
| `-d` | The only USB device |
| `-e` | The only emulator |
| `-s <serial>` | A specific device, as listed by `adb devices`. You can also set it with `export ANDROID_SERIAL=<serial>` |
| `-t <transport_id>` | A specific transport, as listed by `adb devices -l` |

Global options go **before** the command: `adb -s 1234abcd install app.apk`.

### 2.5 Server and state

```shell
adb kill-server && adb start-server  # restart the host server (fixes most "device offline" cases)
adb get-state                        # device / recovery / bootloader / sideload
adb get-serialno
adb wait-for-device shell getprop sys.boot_completed   # prints 1 when boot has finished
```

## 3. Shell and files

```shell
adb shell                            # interactive shell; "exit" to leave
adb shell getprop ro.build.version.release
adb push app.conf /data/local/tmp/   # host -> device
adb pull /sdcard/Download/log.txt .  # device -> host
adb exec-out screencap -p > screen.png   # exec-out: raw binary stdout, no tty/CRLF mangling
adb shell screenrecord /sdcard/demo.mp4  # Ctrl-C to stop (max 3 min), then adb pull
```

+ `/sdcard` is `/storage/emulated/0` (shared storage). `/data/local/tmp` is writable by the `shell` user.
+ `screencap` writes PNG if you pass `-p` **or** the file name ends in `.png`.
  Otherwise it writes a raw dump (small header + pixels), so `screencap 05.jpg` is not a JPEG.
  `-d <display-id>` picks a display (IDs from `dumpsys SurfaceFlinger --display-id`).
  Without a file name, the image goes to stdout, which is what `exec-out` uses.

## 4. Install and remove apps

```shell
adb install app.apk                  # new install
adb install -r app.apk               # replace an existing app, keep its data
adb install -r -d app.apk            # allow a version-code downgrade (debuggable apps / userdebug builds)
adb install -g app.apk               # grant all runtime permissions listed in the manifest
adb install -t app-debug.apk         # allow test-only APKs (android:testOnly)
adb install-multiple base.apk split_config.arm64_v8a.apk   # split APKs

adb uninstall com.example.app
adb shell pm uninstall -k com.example.app       # keep data and cache directories
adb shell pm clear com.example.app              # delete the app's data, keep it installed
```

+ `adb install` takes a **host** path to an APK. `adb uninstall` and `pm` take the **package name**.
+ `adb shell pm install` takes a path **on the device**.
+ Updating a system app with `adb install -r` works only if it is signed with the same key.
  The update goes to `/data/app`, and the original copy stays in `/system`.

## 5. Reboot, root, remount

```shell
adb reboot                           # normal reboot
adb reboot recovery
adb reboot bootloader                # bootloader fastboot mode; use the "fastboot" tool from here
adb reboot fastboot                  # userspace fastbootd (Android 10+, dynamic partitions)
adb reboot sideload                  # recovery, waiting for "adb sideload ota.zip"

fastboot devices                     # adb doesn't work in bootloader mode; fastboot does
```

```shell
adb root                             # restart adbd as root: userdebug/eng builds only (ro.debuggable=1)
adb unroot
adb disable-verity && adb reboot     # once per device, before remount (AVB / dm-verity)
adb remount                          # make /system, /vendor, ... writable (overlayfs on dynamic partitions)
```

On a **user** build, `adb root` fails with "adbd cannot run as root in production builds".

## 6. Bug reports and backups

```shell
adb bugreport bugreport.zip          # logs, dumpsys, tombstones, ANR traces (Android 7+: zip)
```

`adb backup` / `adb restore` are deprecated.
Since Android 12, apps that target API 31+ are excluded from `adb backup` unless they are debuggable.
Don't rely on it.

## 7. Several devices at once

`adb devices` prints a header line, then `serial<TAB>state` lines, then an empty line.
Pick the serials of devices in the `device` state:

```shell
adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
```

Shell functions for `~/.bashrc` (aliases can't take arguments, so use functions):

```shell
adb_serials() { adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'; }

adb_all() {                          # run any adb command on every device
    local s
    for s in $(adb_serials); do
        echo "== $s"
        adb -s "$s" "$@"
    done
}

# Examples
adb_all install -r ~/Downloads/MyApp-release.apk
adb_all uninstall com.example.myapp
adb_all shell pm clear com.example.myapp
adb_all shell getprop ro.build.version.release
adb_all shell am start -a android.intent.action.VIEW -d https://developer.android.com
```

After editing `~/.bashrc`, run `source ~/.bashrc` or open a new terminal.

## Related notes

+ [adb_shell_cmds.md](adb_shell_cmds.md): `am`, `pm`, `cmd`, `settings`, `dumpsys`, `svc`, `input`, ...
+ [logcat_intro.md](logcat_intro.md)
+ [uart_console.md](uart_console.md): the UART debug console, for when adb isn't available yet
+ [../Build/AOSP_envsetup_cmds.md](../Build/AOSP_envsetup_cmds.md), [../AOSP_cfg/virtual_AB.md](../AOSP_cfg/virtual_AB.md)

## Reference

+ [Android Debug Bridge (adb)](https://developer.android.com/tools/adb)
+ [SDK Platform-Tools release notes](https://developer.android.com/tools/releases/platform-tools)
+ [Capture and read bug reports](https://developer.android.com/studio/debug/bug-report)
+ [screencap source (AOSP)](https://android.googlesource.com/platform/frameworks/base/+/main/cmds/screencap/screencap.cpp)
