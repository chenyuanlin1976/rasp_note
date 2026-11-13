# Android shutdown flow: from "Power off" to the PMIC

This note follows a shutdown from the user tapping **Power off** to the PMIC cutting the power rails.
The work passes through 4 layers:

1. **system_server** (`ShutdownThread`): notifies apps, saves framework state, turns off radios.
2. **init**: stops services, unmounts storage, and makes the `reboot()` system call.
3. **Linux kernel**: runs driver shutdown callbacks and calls the power-off handler.
4. **Power-off handler** (PMIC driver or firmware): tells the PMIC to switch off.

The Java framework doesn't call `reboot()` through JNI.
It sets the system property **`sys.powerctl`**, and init does the rest.

## 1. Overview

```text
Power key long press -> PhoneWindowManager -> GlobalActions dialog -> "Power off"
PowerManager.shutdown() / svc power shutdown   (needs the REBOOT permission)
        |
        v
system_server: ShutdownThread
  + ACTION_SHUTDOWN broadcast, save AMS/PMS state, radios off
  + PowerManagerService.lowLevelShutdown(reason)
        |  setprop sys.powerctl "shutdown,<reason>"
        v
init (system/core/init/reboot.cpp)
  + "on shutdown" triggers, SIGTERM/SIGKILL services
  + vold shutdown, unmount or remount read-only, sync
  + reboot(RB_POWER_OFF)
        |  reboot system call (svc #0 on arm64)
        v
kernel (kernel/reboot.c)
  + reboot notifiers, device_shutdown(), syscore_shutdown()
  + machine_power_off() -> power-off handler
        |
        v
PMIC driver over I2C/SPI, or PSCI SYSTEM_OFF -> TF-A (EL3)
        |
        v
PMIC switches off the rails
```

## 2. Framework: `ShutdownThread` in system_server

Entry points:

+ **Power menu**: a long press of the power key makes `PhoneWindowManager` show the `GlobalActions` dialog.
  "Power off" calls `ShutdownThread.shutdown()` through the window manager.
+ **API**: `PowerManager.shutdown()` (system apps with the `REBOOT` permission) goes through `PowerManagerService` to `ShutdownThread`.
  `adb shell svc power shutdown` uses this path.
+ **Automatic**: low-battery and thermal shutdowns take the same path, with a different reason string.

`ShutdownThread` (`frameworks/base/services/core/java/com/android/server/power/ShutdownThread.java`) then:

1. Shows the confirmation dialog (if requested), then a "Shutting down…" dialog. Some vendors show a shutdown animation instead.
2. Holds wake locks so the device doesn't suspend in the middle of the shutdown.
3. Sets `sys.shutdown.requested`.
4. Sends the ordered broadcast **`Intent.ACTION_SHUTDOWN`**, so apps and services can save data, and waits for it for a limited time (about 10 s).
   Apps get a chance to clean up, not a guarantee.
5. Calls `ActivityManagerService.shutdown()` and `PackageManagerService.shutdown()`, which write their state (battery stats, usage stats, package settings) to disk.
6. Turns off the radios: Bluetooth and the cellular modem.
7. Vibrates briefly (if the device has a vibrator), then calls `PowerManagerService.lowLevelShutdown(reason)`.
   This sets `sys.powerctl` to `shutdown,<reason>`, for example `shutdown,userrequested`.

Older Android versions also unmounted storage here (through `MountService`).
In current versions, init and vold unmount storage (see §3).

## 3. init: `sys.powerctl`

init watches `sys.powerctl` and handles shutdown and reboot in `system/core/init/reboot.cpp`:

1. Records the reason, so the next boot can report why the device went down (see §7).
2. Runs the `on shutdown` actions from the `.rc` files.
3. Stops services: `SIGTERM` to all of them, waits up to `ro.build.shutdown_timeout` seconds, then `SIGKILL`.
   Services marked `shutdown critical` in their `.rc` keep running until the end.
4. Shuts down vold (which unmounts storage volumes), turns off zram swap, and calls `sync`.
5. Unmounts the remaining file systems or remounts them read-only, so `/data` is clean on the next boot.
6. Calls bionic's `reboot(RB_POWER_OFF)`, which makes the **`reboot` system call** with `LINUX_REBOOT_CMD_POWER_OFF`.
   For a reboot, init passes `LINUX_REBOOT_CMD_RESTART2` with an argument such as `recovery` or `bootloader`.

`adb shell reboot -p` and `adb reboot` set `sys.powerctl` directly.
They **skip `ShutdownThread`**, so apps don't receive `ACTION_SHUTDOWN`.

## 4. Kernel: `reboot()` and `kernel_power_off()`

The `reboot` system call is `SYSCALL_DEFINE4(reboot, ...)` in **`kernel/reboot.c`**.
It needs `CAP_SYS_BOOT` and checks two magic numbers.
If no power-off handler is registered, the kernel turns the power-off command into a **halt**: the CPUs stop, but the board stays powered.

`kernel_power_off()` then:

1. Calls the **reboot notifier chain** (`register_reboot_notifier()`).
2. Calls **`device_shutdown()`**: each driver's `.shutdown()` callback runs, children before parents.
   Drivers use it to stop DMA, park hardware, or switch off a display panel cleanly.
3. Moves to the reboot CPU, runs `syscore_shutdown()`, and logs `reboot: Power down`.
4. Calls `machine_power_off()`. On arm64, this stops the other CPUs and runs the registered **sys-off handlers**.
   Kernels before 5.19 used a single global `pm_power_off` function pointer instead.

## 5. Power-off handler: who talks to the PMIC

| Handler | Who switches the PMIC off | Example |
| --- | --- | --- |
| PMIC driver, with the DT property `system-power-controller` on the PMIC node | Linux, with a register write over I2C/SPI | RK809 on RK3566 boards (`rk8xx` driver) |
| PSCI `SYSTEM_OFF` (`drivers/firmware/psci/`) | TF-A at EL3, after an SMC from Linux | many arm64 SoCs, where the secure firmware owns the PMIC |
| Power-off drivers in `drivers/power/reset/` | Linux toggles a GPIO or writes a SoC register | `gpio-poweroff`, `syscon-poweroff` |

Whether Linux may touch the PMIC directly depends on the platform.
On Rockchip boards, the kernel's RK809 driver usually does it. On many Qualcomm and other secure platforms, the firmware does.
If several handlers are registered, they run in priority order.

**After power-off**, the PMIC isn't at 0 W.
It keeps a small always-on domain powered from the battery or adapter: the RTC, power-key detection, and often the charger.
A power-key press (or an RTC alarm, or plugging in the charger, depending on the PMIC setup) powers the board up again.

## 6. Shutdown vs. reboot

| Step | Shutdown | Reboot |
| --- | --- | --- |
| Framework | `ShutdownThread`, then `lowLevelShutdown()` | `ShutdownThread`, then `lowLevelReboot()` |
| `sys.powerctl` | `shutdown,<reason>` | `reboot,<reason>` (e.g. `reboot,recovery`) |
| System call | `LINUX_REBOOT_CMD_POWER_OFF` | `LINUX_REBOOT_CMD_RESTART2` with an argument |
| Final step | power-off handler: PMIC off | restart handler: SoC or PMIC reset. The argument may be saved for the bootloader (e.g. to enter recovery) |

## 7. Commands and debugging

```shell
adb shell svc power shutdown            # full framework path (ShutdownThread)
adb shell reboot -p                     # straight to init: no ACTION_SHUTDOWN broadcast
adb reboot recovery                     # reboot with an argument

adb logcat -b all | grep -i shutdown    # ShutdownThread and init messages
adb shell getprop ro.build.shutdown_timeout
adb shell getprop sys.boot.reason       # after the next boot: why the device last went down
```

`sys.boot.reason` uses the canonical format `<type>,<detail>`, such as `shutdown,userrequested` or `reboot,recovery`.

Kernel side: `reboot: Power down` in the console log means the kernel reached `machine_power_off()`.
If the board stays powered after that, no working power-off handler is registered. Check the PMIC's `system-power-controller` property, or the PSCI node, in the device tree.

## Related notes

+ [power_saving.md](power_saving.md): suspend states and Android power modes
+ [../../Linux/suspend_resume_flow.md](../../Linux/suspend_resume_flow.md): what the kernel does for suspend-to-RAM
+ [../../Linux/regulators.md](../../Linux/regulators.md): PMICs and the regulator framework
+ [../HW/input_key_flow.md](../HW/input_key_flow.md): how a key press reaches the framework
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)

## Reference

+ [Canonical boot reason (source.android.com)](https://source.android.com/docs/core/architecture/bootloader/boot-reason)
+ [ShutdownThread.java (cs.android.com)](https://cs.android.com/android/platform/superproject/main/+/main:frameworks/base/services/core/java/com/android/server/power/ShutdownThread.java)
+ [init reboot.cpp (cs.android.com)](https://cs.android.com/android/platform/superproject/main/+/main:system/core/init/reboot.cpp)
+ [kernel/reboot.c (git.kernel.org)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/kernel/reboot.c)
+ [Arm PSCI specification (developer.arm.com)](https://developer.arm.com/documentation/den0022/latest)
