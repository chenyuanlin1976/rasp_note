# logcat vs dmesg on Android

`adb logcat` and `adb shell dmesg` read two different logs.
**logcat** reads the user-space log that `logd` keeps (apps, framework, native daemons, HALs).
**dmesg** reads the **kernel ring buffer** (drivers, hardware, kernel errors).
The examples refer to an RK3566 board running Android 14. Section 6 compares dmesg with the UART console, which prints the same kernel messages.

```text
apps (android.util.Log), framework (Slog),        kernel, drivers (printk, dev_err)
native daemons / HALs (ALOGx, liblog)              Android init (writes to /dev/kmsg)
            │ /dev/socket/logdw                                │
            ▼                                                  ▼
        logd buffers  <──── kernel buffer (optional) ────  kernel ring buffer ──> console (UART)
            │                 and SELinux audit                │
      adb logcat                                         adb shell dmesg
```

## 1. Comparison

| | `adb logcat` | `adb shell dmesg` |
| --- | --- | --- |
| Layer | User space: apps, ART, system services, native daemons, HALs | Kernel: drivers, subsystems, memory, power management, plus Android init's `init:` lines |
| Written with | `android.util.Log`, `Slog`, `ALOGx` (`liblog`) | `printk`, `pr_*`, `dev_err`/`dev_info`, ... |
| Stored in | `logd` RAM buffers (`main`, `system`, `crash`, `events`, ...) | The kernel ring buffer (size set by `CONFIG_LOG_BUF_SHIFT` / `log_buf_len=`) |
| Permission | Works over adb on any build with USB debugging | Usually needs `adb root`: Android sets `kernel.dmesg_restrict=1`, and the `shell` user lacks `CAP_SYSLOG` |
| Timestamps | Wall-clock time (`threadtime` format) | Seconds since boot |
| After a reboot | Gone, unless log persistence is on (`logpersist.start`, userdebug) | Gone. The last kernel log before a panic or reset is in pstore (`/sys/fs/pstore/console-ramoops*`), if enabled |
| Early boot | Only once `logd` runs | From kernel start, but old lines are overwritten when the buffer fills |

## 2. What each one shows

### 2.1 logcat

+ App crashes (`FATAL EXCEPTION` from `AndroidRuntime`) and ANRs
+ Native crashes (`DEBUG` tombstone summaries), in the `crash` buffer
+ `system_server` services: ActivityManager, PackageManager, WindowManager, permission checks
+ Native daemons and HALs: SurfaceFlinger, AudioFlinger, camera, codec, and graphics HALs talking to Rockchip's vendor libraries
+ Binder errors seen by the caller (`DeadObjectException`, failed transactions)

Details and filters are in [logcat_intro.md](logcat_intro.md).

### 2.2 dmesg

+ Driver probing and failures: `probe failed`, `-EPROBE_DEFER`, missing clocks/regulators/GPIOs, device tree errors
+ On RK3566: DRM/VOP and HDMI or panel bring-up, Mali GPU, VPU/RGA, Wi-Fi/Bluetooth module firmware loading, USB, PCIe, eMMC/SD
+ Thermal throttling, out-of-memory kills (`Out of memory: Killed process`), suspend/resume messages
+ Kernel warnings and oops messages (`WARNING:`, `Unable to handle kernel ...`, call traces)
+ Android init: `init: starting service ...`, `init: Service ... exited with status ...`

## 3. Commands

```shell
adb root                                  # userdebug/eng; needed for dmesg on most builds
adb shell dmesg                           # whole buffer
adb shell dmesg -w                        # follow
adb shell dmesg | grep -iE 'error|fail|defer'
adb shell dmesg -c > /dev/null            # clear (root)
adb logcat -b kernel                      # kernel log through logd, if ro.logd.kernel is enabled
adb shell cat /sys/fs/pstore/console-ramoops-0    # kernel log from before the last reboot (if pstore is enabled)
adb bugreport bugreport.zip               # includes the kernel log, also on user builds
```

`dmesg` on Android is toybox's. It supports `-c`, `-w`, `-n <level>`, `-r`, `-t`, but not every option of the util-linux version.

## 4. Messages that appear in both

+ **SELinux denials** (`avc: denied`) are kernel audit messages. They are in `dmesg`, and `logd` also copies them into logcat.
  See [../SELinux/avc_denied.md](../SELinux/avc_denied.md).
+ **Kernel messages** appear in logcat's `kernel` buffer when `logd` reads them.

To line up events from both logs, print logcat with the same clock as dmesg:

```shell
adb logcat -v monotonic               # seconds since boot, like the dmesg timestamps
```

## 5. Which one to use

| Symptom | Start with | Why |
| --- | --- | --- |
| App crash, ANR, permission error | logcat | Java stack trace, `ActivityManager` messages |
| `system_server` crash or soft reboot (boot animation restarts) | logcat (`-b crash`, `-b system`) | The runtime restarts; the kernel keeps running |
| HAL or vendor library error (camera, codec, audio) | logcat first, then dmesg | The HAL logs to logcat; the driver it calls logs to dmesg |
| Black screen, HDMI doesn't sync | dmesg | DRM/VOP, HDMI, panel driver messages |
| Peripheral not detected (touch, camera sensor, Wi-Fi) | dmesg | Probe errors, I2C/SDIO/USB errors, firmware loading |
| Random hard reboots, kernel panic | pstore after reboot, or the UART console | The panic message isn't in `dmesg` after the reboot |
| Stuck before Android starts (no adb) | [UART console](uart_console.md) | Neither log is reachable without adb |

## 6. dmesg vs the UART console

While Android runs, the [UART console](uart_console.md) often shows the same text as `dmesg`.
That's because the kernel writes each message to its ring buffer **and** prints it on the console device (`console=` on the kernel command line).
They still differ in what they cover:

| | `adb shell dmesg` | UART console |
| --- | --- | --- |
| What it is | A command that reads the kernel ring buffer, run over adb or in any shell on the device | A serial port the kernel prints to, read through a USB-to-UART adapter |
| Before the kernel | Nothing | Boot ROM loader and U-Boot output |
| Kernel messages | All levels, from kernel start, until the buffer wraps | Only messages more urgent than the console log level (`loglevel=`, `quiet`, `dmesg -n`) |
| Needs | A running system and a shell | Only power and the three wires |
| Kernel panic | Lost on reboot (read pstore instead) | Printed live, up to the last message before the reset |

+ **Only UART helps** when the board never reaches a shell: a bad `.dtb`, a U-Boot misconfiguration, a panic before `adbd` starts, or a bootloop.
  The error (for example, eMMC fails to initialize, or the root filesystem can't be mounted) is printed right before the hang or reset.
+ **dmesg is better** for messages the console log level filters out, for searching with `grep`, and on boards without access to the debug UART.

## Related notes

+ [logcat_intro.md](logcat_intro.md): logcat commands, buffers, filters, formats
+ [uart_console.md](uart_console.md): the serial console, for boot failures and panics
+ [adb_intro.md](adb_intro.md): `adb root`, bug reports
+ [../SELinux/avc_denied.md](../SELinux/avc_denied.md): reading SELinux denials
+ [../../Linux/DeviceTree/dts_driver_probe.md](../../Linux/DeviceTree/dts_driver_probe.md): debugging a driver that doesn't probe

## Reference

+ [Logcat command-line tool](https://developer.android.com/tools/logcat)
+ [Understanding logging (AOSP)](https://source.android.com/docs/core/tests/debug/understanding-logging)
+ [Message logging with printk (kernel docs)](https://docs.kernel.org/core-api/printk-basics.html)
+ [`/proc/sys/kernel/` documentation: `dmesg_restrict`, `printk` (kernel docs)](https://docs.kernel.org/admin-guide/sysctl/kernel.html)
