# Linux system suspend and resume flow

This note lists what the kernel does after something writes `mem` to `/sys/power/state`, and how it comes back on a wakeup interrupt.
On Android, the `system_suspend` service writes it as soon as no wake lock is held.
For the sleep states themselves (s2idle, deep) and Android's power modes, see [power_saving.md](../Android/AOSP_cfg/power_saving.md).

## 1. Overview

```text
echo mem > /sys/power/state        (Android: system_suspend)
  |
  +- PM_SUSPEND_PREPARE notifiers, sync file systems
  +- freeze user space, then freezable kernel threads
  +- suspend devices: prepare -> suspend -> suspend_late -> suspend_noirq
  |                   (children before parents)
  |
  +- s2idle: all CPUs stay online, enter their deepest cpuidle state
  |
  +- deep:   non-boot CPUs offline -> IRQs off -> syscore_suspend()
  |          -> PSCI SYSTEM_SUSPEND (SMC) -> TF-A: DRAM self-refresh,
  |             PMIC switches rails to their sleep state
  |
  ... wakeup interrupt (RTC, GPIO/key, modem, Wi-Fi, USB) ...
  |
  +- the same steps in reverse: devices resume (parents first),
     tasks thawed, PM_POST_SUSPEND notifiers
```

## 2. Entering suspend

1. **Trigger**: a write to `/sys/power/state`.
   Android's `system_suspend` first reads and writes `/sys/power/wakeup_count`, so a wakeup event that arrives during the decision isn't lost.
2. **Preparation**: the kernel calls the `PM_SUSPEND_PREPARE` notifiers and syncs file systems (unless `CONFIG_SUSPEND_SKIP_SYNC` is set).
3. **Freeze tasks**: `freeze_processes()` stops all user-space tasks, then `freeze_kernel_threads()` stops the kernel threads marked freezable.
   After this, no task reads or writes files or touches hardware. The console is suspended next.
4. **Suspend devices**: the PM core runs the drivers' callbacks in 4 phases: `prepare`, `suspend`, `suspend_late`, `suspend_noirq`.
   Children are suspended before their parents. For example, a touchscreen is suspended before its I2C controller, which is still needed to talk to it.
   Drivers save state, switch off clocks and regulators, and arm their wakeup interrupt if the device should wake the system.
5. **Enter the sleep state**: this step depends on the `mem_sleep` mode (see §3).

If a wakeup event arrives at any point in this sequence, the suspend is **aborted** and the kernel resumes the parts already suspended.
On Android, suspend aborts are common and normal.

## 3. s2idle vs. deep: the last step

**s2idle (suspend-to-idle)**:

+ All CPUs stay online. The kernel suspends timekeeping and puts every CPU into its deepest `cpuidle` state (on arm64, PSCI `CPU_SUSPEND`).
+ There is no final call into platform firmware.
  The SoC's power rails stay up, apart from what drivers switched off in step 4 and what the idle states power down.
+ Any enabled wakeup interrupt resumes the CPUs directly, so wake-up is fast.

**deep (suspend-to-RAM)**:

1. The platform `prepare` callbacks run, then the **non-boot CPUs are taken offline** (CPU hotplug). Only the boot CPU keeps running.
2. Interrupts are disabled on the boot CPU and `syscore_suspend()` runs (timekeeping, interrupt controller, and other core code without a struct device).
3. `suspend_ops->enter()`: on arm64, the kernel issues PSCI **`SYSTEM_SUSPEND`** via an SMC to **TF-A** at EL3.
4. TF-A's platform code puts **DRAM into self-refresh** and powers down the CPU cluster and most of the SoC.
   It then signals the PMIC (on many boards, with a dedicated sleep pin) to switch the rails to their **sleep state**.
   The kernel's PMIC driver programmed those states beforehand from the `regulator-state-mem` nodes in the device tree (see [regulators.md](regulators.md#3-describing-rails-in-the-device-tree)).
5. A small always-on domain stays powered: wakeup logic, the GPIO bank used for wakeup, the RTC, and DRAM self-refresh.

## 4. Wakeup and resume

Wakeup sources must be enabled before suspend:

+ In the device tree, the `wakeup-source` property marks a device as able to wake the system (for example, a `gpio-keys` power key).
+ In the driver, `device_init_wakeup()` and `enable_irq_wake()` arm the interrupt.
+ At runtime, `/sys/devices/.../power/wakeup` shows `enabled` or `disabled` for each device.

On a wakeup interrupt, the kernel runs the suspend steps in reverse:

1. deep only: TF-A restores the platform, and the boot CPU continues in the kernel's resume entry point. Then `syscore_resume()` runs, interrupts are enabled, and the non-boot CPUs come back online.
2. Devices resume in 4 phases: `resume_noirq`, `resume_early`, `resume`, `complete`. Parents resume before their children.
3. The console resumes, tasks are thawed, and the `PM_POST_SUSPEND` notifiers run.

On Android, the wakeup event is handled while a wake lock (kernel wakeup source) is held.
When no wake lock is left, `system_suspend` suspends again.

## 5. Driver callbacks

A driver implements system sleep through `struct dev_pm_ops`:

| Callback pair | When it runs |
| --- | --- |
| `prepare` / `complete` | first and last; no new children may be registered in between |
| `suspend` / `resume` | the main phase: save state, stop the device |
| `suspend_late` / `resume_early` | after or before runtime PM is disabled |
| `suspend_noirq` / `resume_noirq` | with device interrupts disabled |

Most drivers implement only `suspend` and `resume`, for example with `DEFINE_SIMPLE_DEV_PM_OPS()` in recent kernels, or `SIMPLE_DEV_PM_OPS()` in older ones.

## 6. Debugging

```shell
cat /sys/power/mem_sleep                          # s2idle [deep]
ls /sys/power/suspend_stats/                      # success, fail, last_failed_dev, ...
cat /sys/kernel/debug/wakeup_sources              # which sources woke or blocked suspend (debugfs)

echo 1 > /sys/power/pm_print_times                # log each device's suspend/resume time
echo 1 > /sys/power/pm_debug_messages             # more PM core messages
echo devices > /sys/power/pm_test                 # CONFIG_PM_DEBUG: stop after device suspend,
echo mem > /sys/power/state                       #   wait 5 s, then resume
echo none > /sys/power/pm_test

rtcwake -m mem -s 10                              # Linux PC: suspend, RTC wakes it after 10 s
dmesg | grep -E "PM:|suspend|resume"
```

+ `pm_test` levels, from shallowest to deepest: `freezer`, `devices`, `platform`, `processors`, `core`. They help find the step at which suspend or resume breaks.
+ Kernel parameter `no_console_suspend` keeps the serial console working during suspend, so late messages aren't lost.
+ Android: `adb shell dumpsys suspend_control_internal` shows the suspend service's wake locks and statistics on recent versions. `adb shell dumpsys power` shows the framework's wake locks.

## Related notes

+ [../Android/AOSP_cfg/power_saving.md](../Android/AOSP_cfg/power_saving.md): sleep states, s2idle vs. deep, Android opportunistic suspend
+ [../Android/AOSP_cfg/shutdown_flow.md](../Android/AOSP_cfg/shutdown_flow.md): the power-off path
+ [regulators.md](regulators.md): PMICs, `regulator-state-mem`
+ [../Android/HW/input_key_flow.md](../Android/HW/input_key_flow.md): `gpio-keys` and `wakeup-source`
+ [sysfs_intro.md](sysfs_intro.md): `/sys/power/`

## Reference

+ [System suspend code flows (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/suspend-flows.html)
+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
+ [Device power management basics (docs.kernel.org)](https://docs.kernel.org/driver-api/pm/devices.html)
+ [Debugging hibernation and suspend (docs.kernel.org)](https://docs.kernel.org/power/basic-pm-debugging.html)
+ [Power management (source.android.com)](https://source.android.com/docs/core/power)
