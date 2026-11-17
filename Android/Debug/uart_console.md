# UART debug console on Android (RK3566)

The **UART debug console** is a serial port wired directly to the SoC.
It works from power-on, so it shows the bootloader, the kernel, and Android init, and on debuggable builds it gives you a shell.
This note compares it with adb/logcat, then covers wiring, the Android `console` service, and fixes for "text comes out but I can't type".
The examples use an RK3566 board running Android 14.

## 1. UART console vs adb/logcat

| | adb / logcat | UART console |
| --- | --- | --- |
| Layer | Android user space: apps, framework, native daemons (plus the kernel log with `dmesg` / `logcat -b kernel`) | Bootloader, kernel, Android init, then a shell |
| Connection | USB or TCP/IP to `adbd` | Three wires (TX, RX, GND) to the board's debug UART, plus a USB-to-UART adapter |
| Available | Once init starts `adbd` (in Android or recovery) | From power-on, including the boot ROM loader and U-Boot |
| When things break | Survives an app or `system_server` crash (logd keeps running), but is gone on a kernel panic, a hang, or a USB failure | Shows early boot failures and the kernel panic message; after a hard hang it shows nothing new and the shell no longer responds |
| Access | Developer options + RSA authorization; `adb root` only on userdebug/eng | On userdebug/eng: a shell as user `shell` (`su` for root). On user builds: usually log output only |
| Speed | Fast file transfer (`adb push/pull`) | A serial line; no file transfer |

| Task | Use | Why |
| --- | --- | --- |
| App crash, UI bug, framework issue | adb | `logcat` filters, `dumpsys`, bug reports |
| Device stuck at the boot logo or bootlooping | UART | Shows the U-Boot/kernel messages and the panic or driver failure |
| Driver bring-up | UART | Kernel log from the first line, even before `adbd` exists |
| Flashing partitions | USB tools (`fastboot`, Rockchip `rkdeveloptool`/RKDevTool) | UART is only used to stop U-Boot and enter those modes (§6) |
| Pulling files, running test scripts | adb | Much faster than a serial line |

Logs from before a crash or reboot can also be read afterwards over adb from pstore (`/sys/fs/pstore/console-ramoops*`), see [logcat_intro.md](logcat_intro.md#6-when-logcat-isnt-enough).

## 2. Wiring and terminal settings

+ **Pins**: on RK3566 boards the debug UART is normally **UART2** (`fe660000.serial`, pins `UART2_TX_M0` = GPIO0_D1 and `UART2_RX_M0` = GPIO0_D0).
  Check your board's schematic; many boards bring these out on a 3-pin debug header.
+ **Wiring**: board TX → adapter RX, board RX → adapter TX, GND ↔ GND. Don't connect the adapter's VCC.
+ **Levels**: 3.3 V TTL. Never connect RS-232 levels (±12 V) directly.
+ **Settings**: **1500000** baud on Rockchip's default firmware (some vendors use 115200), 8N1, **no flow control**.

```shell
sudo usermod -aG dialout $USER          # once; log in again
picocom -b 1500000 /dev/ttyUSB0         # exit: Ctrl+A Ctrl+X
minicom -D /dev/ttyUSB0 -b 1500000      # Ctrl+A O -> Serial port setup -> Hardware Flow Control: No
```

+ Leave **local echo off**. The device's tty echoes what you type, so local echo shows every character twice.
  If nothing you type appears, the keystrokes aren't reaching a reader (§5.1).
+ Garbage characters usually mean the wrong baud rate. Some adapters (and Windows drivers) can't do 1500000; adapters based on FTDI or CP2102N can.

## 3. What you see at each boot stage

| Stage | Output | Input |
| --- | --- | --- |
| Boot ROM / DDR init / SPL | Short loader banners, DDR training | None |
| U-Boot | U-Boot log; a `=>` prompt if autoboot is interrupted | U-Boot commands (§6) |
| Kernel | `printk` messages up to the console log level | None until a shell runs |
| Android init | `init:` lines (init writes to the kernel log) | None |
| Android booted (userdebug/eng) | A `console:/ $` prompt after you press Enter | Shell commands |

App and framework logs (`Log.d()`, logd) **don't** go to the UART. Run `logcat` in the console shell to see them there.

## 4. The Android `console` service

AOSP's `system/core/rootdir/init.rc` already defines the shell on the serial console (abbreviated):

```text
service console /system/bin/sh
    class core
    console
    disabled
    user shell
    group shell log readproc
    seclabel u:r:shell:s0
    setenv HOSTNAME console

on property:ro.debuggable=1
    start console
```

+ It starts only when **`ro.debuggable=1`** (userdebug and eng builds).
  On user builds it doesn't run, so the UART is output-only unless the vendor removed the kernel console as well.
+ The `console` option attaches the shell to `/dev/console`, or to the device named by **`androidboot.console`** (read by init as `ro.boot.console`).
  Rockchip's Android kernels usually route the debug UART through the **FIQ debugger**, so the console device is `ttyFIQ0` instead of `ttyS2`.
+ The shell runs as user **`shell`** in the `shell` SELinux domain, like `adb shell`. Use `su` for root (userdebug/eng only).
+ You normally don't need to add this service. If your build lacks it, check whether a device `.rc` overrides it, rather than adding a second copy.

## 5. Troubleshooting

### 5.1 Logs come out, but typing does nothing

Work through these in order:

1. **Flow control**: hardware flow control on the host blocks transmission when CTS isn't wired. Turn it off (§2).
2. **RX wire**: output only needs board TX. If input never works, check the adapter TX → board RX connection.
3. **Build type and service** (check over adb):

   ```shell
   adb shell getprop ro.debuggable          # must be 1
   adb shell getprop init.svc.console       # running / stopped / empty if not defined
   adb shell getprop ro.boot.console        # e.g. ttyFIQ0
   adb shell cat /proc/cmdline              # console=..., androidboot.console=...
   adb shell cat /proc/bootconfig           # Android 12+: androidboot.* may be here instead
   ```

4. **FIQ debugger prompt**: if pressing Enter shows `debug>`, you are in Rockchip's FIQ debugger. Type `console` to switch to the Linux console.

### 5.2 Kernel messages flood the console

Only kernel `printk` messages (including init's `init:` lines) are printed on the console. Lower the **console log level** so only emergencies get through:

```shell
su                               # in the console shell, userdebug/eng
dmesg -n 1                       # same as: echo 1 > /proc/sys/kernel/printk
cat /proc/sys/kernel/printk      # first field = console log level
```

The messages are still recorded: `dmesg` and `logcat -b kernel` show them.
The setting is lost on reboot. To make it permanent, add `loglevel=<n>` to the kernel command line.

## 6. U-Boot over UART

+ Hold **Ctrl+C** (or press a key, depending on the U-Boot build) while powering on to stop autoboot and get the `=>` prompt.
  Rockchip's Android U-Boot often has a very short boot delay, so start pressing before power is applied.
+ Useful commands: `printenv`, `setenv`, `boot`, `reset`, and in Rockchip U-Boot `fastboot usb 0` and `rockusb 0 mmc 0`, which wait for a USB flashing tool on the host.
+ From a running Android shell, `reboot bootloader` (fastboot) and `reboot loader` (Rockchip Loader/rockusb mode) do the same without UART.

## Related notes

+ [adb_intro.md](adb_intro.md): adb setup, including adb over TCP started from the serial console
+ [logcat_intro.md](logcat_intro.md): logcat buffers, kernel log, pstore
+ [adb_shell_cmds.md](adb_shell_cmds.md): commands to run in the shell
+ [../../Linux/dts_intro.md](../../Linux/dts_intro.md): enabling `&uart2` in the board device tree
+ [../../Linux/suspend_resume_flow.md](../../Linux/suspend_resume_flow.md): `no_console_suspend` for debugging suspend

## Reference

+ [Android init language (AOSP README)](https://android.googlesource.com/platform/system/core/+/main/init/README.md)
+ [Implementing bootconfig (AOSP)](https://source.android.com/docs/core/architecture/bootloader/implementing-bootconfig)
+ [Linux serial console (kernel docs)](https://docs.kernel.org/admin-guide/serial-console.html)
+ [Message logging with printk (kernel docs)](https://docs.kernel.org/core-api/printk-basics.html)
+ [Logcat command-line tool](https://developer.android.com/tools/logcat)
