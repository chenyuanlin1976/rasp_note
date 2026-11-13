# Power saving on Android: kernel suspend states and framework modes

Android saves power on two separate layers:

+ **Kernel layer (Linux system sleep):** when nothing holds a wake lock, the kernel suspends the whole system into a sleep state such as **s2idle** or **deep** (suspend-to-RAM).
+ **Framework layer (Android policy):** Doze, App Standby Buckets, and Battery Saver limit what apps may do, so the kernel is woken up less often and stays suspended longer.

None of this is specific to Android 14; the mechanisms below have been in place for many releases.

## 1. The two layers at a glance

| Layer | Examples | Decided by | What it controls |
| --- | --- | --- | --- |
| Kernel | s2idle, deep (suspend-to-RAM), CPU idle states | Linux PM core, platform firmware, `system_suspend` | Whether the CPUs, devices, and RAM are running or suspended |
| Framework | Doze, App Standby Buckets, Battery Saver | `DeviceIdleController`, `AppStandbyController`, `PowerManagerService` | When apps may use network, jobs, alarms, and wake locks |

## 2. Linux system sleep states

The kernel exposes its sleep states in two sysfs files:

+ `/sys/power/state`: the states the system can enter: `freeze`, `standby`, `mem`, `disk`.
+ `/sys/power/mem_sleep`: what `mem` actually means on this platform: `s2idle`, `shallow`, or `deep`. The current choice is shown in brackets, e.g. `s2idle [deep]`. The default can be set with the kernel parameter `mem_sleep_default=`.

| Kernel name | Also called | Writing to `/sys/power/state` | x86 ACPI equivalent |
| --- | --- | --- | --- |
| s2idle | Suspend-to-idle, freeze | `freeze`, or `mem` when `mem_sleep` is `s2idle` | S0 low-power idle (S0ix, Modern Standby) |
| shallow | Standby, power-on suspend | `standby`, or `mem` when `mem_sleep` is `shallow` | S1 |
| deep | Suspend-to-RAM | `mem` when `mem_sleep` is `deep` | S3 |
| hibernation | Suspend-to-disk | `disk` | S4 |

Not every platform supports every state. s2idle is always available; `shallow` and `deep` need platform support (ACPI on x86, PSCI `SYSTEM_SUSPEND` or a vendor driver on Arm). Phones don't use hibernation.

## 3. Suspend-to-idle (s2idle)

s2idle is a software-only sleep state. The kernel:

1. freezes user-space tasks,
2. suspends devices (the same driver suspend callbacks as for deep),
3. suspends timekeeping,
4. puts all CPUs into their deepest `cpuidle` state. The CPUs stay **online**; they are only idle.

There is no final call into platform firmware, so wake-up is fast: any enabled wakeup interrupt resumes the CPUs directly.

+ **Pros:** works on every platform; fast resume; on SoCs with good idle states (deep cluster/system power-down, DRAM self-refresh), the power draw can come close to deep.
+ **Cons:** on platforms whose idle states are shallow, more of the SoC stays powered, so it drains more than deep.

## 4. Suspend-to-RAM (deep)

Deep sleep goes one step further than s2idle. After freezing tasks and suspending devices, the kernel:

1. takes the non-boot CPUs offline,
2. hands control to platform firmware (ACPI S3 on x86, PSCI `SYSTEM_SUSPEND` to the secure firmware such as TF-A on Arm),
3. the firmware and PMIC then power down the CPU cluster and most of the SoC, and put DRAM into **self-refresh** so its contents survive.

+ **Pros:** usually the lowest power draw short of powering off.
+ **Cons:** slower resume (firmware path, restoring power rails and CPU state, bringing the other CPUs back online); needs platform support.

The step-by-step kernel flow for both states is in [suspend_resume_flow.md](../../Linux/suspend_resume_flow.md).

## 5. s2idle vs. deep

| Feature | s2idle (suspend-to-idle) | deep (suspend-to-RAM) |
| --- | --- | --- |
| Driven by | Kernel only (`cpuidle`) | Kernel + platform firmware (ACPI / PSCI) |
| User space | Frozen | Frozen |
| Devices | Suspended | Suspended |
| CPUs | Online, in their deepest idle state | Non-boot CPUs offline; cluster powered down |
| RAM | Powered; self-refresh only if the SoC idle state does it | Self-refresh |
| Resume | Fast | Slower (firmware and CPU bring-up) |
| Power draw | Platform dependent; higher than deep on weak idle hardware | Lowest |

## 6. How Android enters suspend

Android uses **opportunistic suspend**: the system suspends as soon as nobody holds a wake lock, and resumes on any wakeup interrupt.

```text
screen off
  -> PowerManagerService releases its display suspend blocker
  -> no wake locks held (app PARTIAL_WAKE_LOCKs, framework, kernel wakeup sources)
  -> system_suspend (android.system.suspend) writes "mem" to /sys/power/state
  -> kernel freezes tasks, suspends devices, enters the mem_sleep mode (s2idle or deep)
  ...
  -> wakeup interrupt (RTC alarm, modem, Wi-Fi, power key)
  -> kernel resumes; a wake lock is held while the event is handled
  -> no wake locks again -> suspend again
```

Points that are often confused:

+ Android does **not** go into s2idle first and later switch to deep. Each suspend uses the single mode that `/sys/power/mem_sleep` selects for the platform; which one a phone uses is a vendor/kernel decision.
+ "Deep sleep" in battery statistics apps means "kernel suspended" (as opposed to "awake"), whatever the `mem_sleep` mode is.
+ Doze does not put the kernel to sleep. It restricts apps (network, jobs, alarms, wake locks), so there are fewer wakeups and the kernel stays suspended longer.
+ The screen being off is not the same as suspended: while any wake lock is held, the CPUs keep running.

## 7. Android framework power modes

+ **Doze mode** (Android 6.0+; light doze since Android 7.0): `DeviceIdleController` restricts network, jobs, syncs, alarms, and wake locks while the device is screen-off and unplugged (deep doze also needs the device to be stationary). Work runs in short maintenance windows. Details in [dream_screensaver.md](dream_screensaver.md#5-doze-mode-device-idle).
+ **App Standby Buckets** (Android 9+): each app is put in a bucket by how recently and often it is used: Active, Working set, Frequent, Rare, and Restricted (Android 12+). Lower buckets get fewer jobs, alarms, and network access.
+ **Battery Saver** (Android 5.0+): user-enabled or triggered at a battery level. It limits background work and location, may turn off animations, and switches to the dark theme on newer versions.
+ **Vendor extreme modes** (e.g. Pixel's Extreme Battery Saver, Samsung's power saving modes): pause most apps except a user-chosen set and cut background activity further. Behavior depends on the vendor.

## 8. PC sleep states (ACPI) for comparison

Phones use device tree and PSCI instead of ACPI, but PC notes (for example, [Wake-on-LAN](../../Comm/WoL_intro.md)) use the ACPI names:

| ACPI state | Meaning | Linux name |
| --- | --- | --- |
| S0 | Working. S0ix / Modern Standby is a low-power idle within S0 that can still run background tasks | s2idle |
| S1 | Power-on suspend: CPUs stop executing, power and context are kept | shallow (standby) |
| S2 | Like S1, but the CPU is powered off; rarely implemented | n/a |
| S3 | Suspend-to-RAM: almost everything off, RAM in self-refresh | deep |
| S4 | Hibernation: RAM image written to disk, system powered off | disk |
| S5 | Soft off: shut down; standby power may remain for Wake-on-LAN or USB charging | power off |

## 9. Commands

```shell
# Kernel sleep states (Android or Linux)
adb shell cat /sys/power/state
adb shell cat /sys/power/mem_sleep          # e.g. "s2idle [deep]"
adb shell ls /sys/power/suspend_stats/      # success, fail, last_failed_dev, ...

# Wake locks and Doze
adb shell dumpsys power | grep -i "wake lock"
adb shell dumpsys deviceidle                # Doze state
adb shell am get-standby-bucket <package>

# Battery Saver on/off
adb shell settings put global low_power 1
adb shell settings put global low_power 0
```

On a Linux PC, `echo deep | sudo tee /sys/power/mem_sleep` selects deep for the next suspend, and `systemctl suspend` suspends.

## Related notes

+ [dream_screensaver.md](dream_screensaver.md): dreams, doze dream, and Doze mode
+ [../../Linux/suspend_resume_flow.md](../../Linux/suspend_resume_flow.md): kernel suspend and resume, step by step
+ [shutdown_flow.md](shutdown_flow.md): from "Power off" to the PMIC
+ [../../Linux/regulators.md](../../Linux/regulators.md): PMICs and power rails
+ [../App/app_background_limits.md](../App/app_background_limits.md): wake locks and background limits for apps
+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)
+ [../../Linux/sysfs_intro.md](../../Linux/sysfs_intro.md): `/sys/power/`
+ [../../Comm/WoL_intro.md](../../Comm/WoL_intro.md): waking a PC from sleep or soft off

## Reference

+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
+ [System suspend code flows (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/suspend-flows.html)
+ [Power management (source.android.com)](https://source.android.com/docs/core/power)
+ [Optimize for Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
+ [App Standby Buckets](https://developer.android.com/topic/performance/appstandby)
