# RK3566 system suspend: s2idle vs. deep, PMIC, and wakeup sources

This note covers the RK3566-specific parts of system suspend: what the two `mem_sleep` modes do on this SoC, how the RK809/RK817 PMIC is involved, which devices can wake the board, and how to track down high standby current.
The generic parts are in other notes:

+ Android side (wake locks, `PowerManagerService`, `system_suspend`): [sleep_flow.md](../../Android/AOSP_cfg/sleep_flow.md)
+ Sleep states in general (`/sys/power/state`, `mem_sleep`, Doze): [power_saving.md](../../Android/AOSP_cfg/power_saving.md)
+ Kernel steps (freeze tasks, device callbacks, PSCI): [suspend_resume_flow.md](suspend_resume_flow.md)

## 1. Where the RK3566 parts fit

Android decides **when** to suspend: the `system_suspend` service (not `system_server`) writes `mem` to `/sys/power/state` as soon as no wake lock is held.
`/sys/power/mem_sleep` decides **how** the kernel suspends, and on RK3566 the deep path ends in Rockchip's TF-A and the PMIC.

```text
PowerManagerService (system_server): screen off, releases its suspend blocker
  -> system_suspend: no wake locks left -> wakeup_count handshake
  -> echo mem > /sys/power/state
  -> kernel: freeze tasks, suspend drivers (dev_pm_ops callbacks)
  -> /sys/power/mem_sleep selects the last step:
       s2idle: CPUs stay online, enter their deepest cpuidle state
       deep:   PSCI SYSTEM_SUSPEND -> TF-A (BL31) -> DDR self-refresh,
               PLLs off, logic powered down, PMIC sleep pin -> rails to sleep state
  ... wakeup interrupt (power key, RTC alarm, GPIO0 pin, ...) ...
  -> resume in reverse order
```

## 2. s2idle vs. deep on RK3566

| | `s2idle` (suspend-to-idle) | `deep` (suspend-to-RAM) |
| --- | --- | --- |
| Last step | Kernel only: every CPU enters its deepest `cpuidle` state (PSCI `CPU_SUSPEND`) | Non-boot CPUs offline, then PSCI `SYSTEM_SUSPEND` to TF-A |
| CPUs | Online but idle; idle states may power-gate the cores | Cluster powered down |
| Clocks and logic | PLLs and the logic domain stay up; drivers have gated their own clocks | TF-A turns off PLLs and powers down most of the SoC, depending on the sleep config (§5) |
| DDR | Powered, normal operation | Self-refresh |
| PMIC rails | Stay in their run state, except those that drivers switched off | Switched to the `regulator-state-mem` settings when the PMIC sleep pin is asserted |
| Resume | Fast | Slower (TF-A restores the platform, CPUs come back online) |
| Standby current | Higher | Lowest short of power-off |

In both modes, user space is frozen and every driver's suspend callback has run; the modes differ only in the last step.
Battery-stats "deep sleep" means "kernel suspended" in either mode.

## 3. Selecting the mode

```shell
adb shell cat /sys/power/mem_sleep            # e.g. "s2idle [deep]"; brackets = current mode

adb root                                      # userdebug/eng build
adb shell "echo deep > /sys/power/mem_sleep"  # next suspends use deep
adb shell "echo s2idle > /sys/power/mem_sleep"
```

+ The bracketed entry is the mode the next `echo mem > /sys/power/state` uses. If only `[s2idle]` is listed, the platform didn't register deep (no PSCI `SYSTEM_SUSPEND` support in the TF-A or kernel).
+ A write to `mem_sleep` lasts only until reboot. To make it permanent, add `mem_sleep_default=deep` (or `s2idle`) to the kernel command line, or select the mode in an init `.rc` script (`write /sys/power/mem_sleep deep`).
+ Writing needs root. On a user build, set it with the command line or an init script, not with adb.

## 4. The PMIC (RK809 / RK817)

RK3566 boards typically use the **RK809** (or the RK817, which adds a charger) on I2C0, which is in the always-on PMU domain.
Its part in suspend:

+ **Rail sleep states**: at boot, the kernel's `rk808-regulator` driver programs each rail's suspend state from its `regulator-state-mem` node (on/off, voltage). See [regulators.md](regulators.md#3-describing-rails-in-the-device-tree).
+ **Sleep pin**: in deep, TF-A asserts the SoC's sleep signal to the PMIC, and the PMIC switches all rails to those states at once. The I2C bus isn't used at that point. In the Rockchip BSP device trees, the PMIC node selects this pin function with a `pmic-sleep` pinctrl state.
+ **RTC and power key**: the PMIC's RTC (`rtc-rk808`) and power key (`rk805-pwrkey`) stay powered and can wake the SoC through the PMIC interrupt line on GPIO0.

The PMIC doesn't "refuse" to cut power. If standby current is high, look for these causes:

+ **Suspend never happened**: a wake lock or wakeup source kept the system awake, or a driver's suspend callback returned an error. A driver error **aborts** the suspend, and the kernel resumes the devices it already suspended (see `last_failed_dev` in §7).
+ **Rails left on**: a rail without `regulator-off-in-suspend` keeps supplying a peripheral that draws current.
+ **Leakage through I/O**: a powered peripheral back-powers an unpowered domain through a pull-up or a driven pin, or a pin floats. Check the pin states and pull settings the drivers select for sleep (`pinctrl-names = "default", "sleep"`).
+ **Peripherals not in low-power mode**: Wi-Fi, modem, Ethernet PHY, or display bridges whose drivers don't put them into their own low-power state.

## 5. Rockchip BSP sleep configuration

In Rockchip's BSP kernel (not mainline), a `rockchip-suspend` node tells TF-A what to power down in deep and which wakeup sources to keep.
It is defined in the SoC `.dtsi` with `status = "disabled"`, and board files enable and tune it:

```dts
&rockchip_suspend {
    status = "okay";
    rockchip,sleep-debug-en = <1>;              /* TF-A prints a sleep/wake summary on the UART */
    rockchip,sleep-mode-config = <
        (0
        | RKPM_SLP_ARMOFF_LOGOFF                 /* CPU cluster and logic domain off */
        | RKPM_SLP_CENTER_OFF
        | RKPM_SLP_HW_PLLS_OFF                   /* PLLs off */
        | RKPM_SLP_PMIC_LP                       /* assert the PMIC sleep pin */
        )
    >;
    rockchip,wakeup-config = <
        (0
        | RKPM_GPIO_WKUP_EN                      /* GPIO0 pins can wake the SoC */
        )
    >;
};
```

+ The flag names come from `include/dt-bindings/suspend/rockchip-rk3568.h` in the BSP (RK3566 shares the RK3568 files). Check that header for the full list, because flags differ between BSP releases.
+ With the logic domain off, the GPIO1–GPIO4 banks lose power. Wakeup pins (power key, external RTC, modem ring) should be on **GPIO0**, which is in the PMU domain.
+ The node is read by the BSP's `rockchip_pm_config` driver and passed to TF-A, which on the BSP is a prebuilt BL31 binary from Rockchip's `rkbin` repository.

## 6. Wakeup sources

A device wakes the system only if its interrupt is armed for wakeup:

+ Device tree: `wakeup-source;` on the device node, for example on `gpio-keys` (see [input_key_flow.md](../../Android/HW/input_key_flow.md#21-device-tree-gpio-keys)) or on the PMIC node for its power key and RTC.
+ Driver: `device_init_wakeup()` and `enable_irq_wake()`.
+ Runtime: `/sys/devices/.../power/wakeup` shows `enabled` or `disabled`.
+ deep on the BSP: the source must also be allowed by `rockchip,wakeup-config` (§5).

On Android, a key wakes the screen only if its key layout entry has the `WAKE` flag; otherwise the kernel resumes, the key is handled, and the system suspends again.

## 7. Debugging

```shell
adb shell cat /sys/power/mem_sleep                       # which mode is used
adb shell cat /sys/power/suspend_stats/success           # does the board suspend at all?
adb shell cat /sys/power/suspend_stats/fail
adb shell cat /sys/power/suspend_stats/last_failed_dev   # driver whose suspend callback failed
adb shell dumpsys suspend_control_internal               # native wake locks (recent releases)
adb shell cat /sys/kernel/debug/wakeup_sources           # root, debugfs: who blocks or wakes
adb shell cat /sys/kernel/debug/regulator/regulator_summary   # rail states before suspend
adb shell dmesg | grep -i -E "PM:|suspend|resume|wakeup"
```

+ Watch the UART console while suspending. With `no_console_suspend` on the kernel command line, late kernel messages are kept; with `rockchip,sleep-debug-en`, TF-A prints which domains were off and what woke the SoC. See [uart_console.md](../../Android/Debug/uart_console.md).
+ Measure the board's input current in both modes. If deep is no better than s2idle, check the sleep config (§5) and the rails left on (§4).

## Related notes

+ [suspend_resume_flow.md](suspend_resume_flow.md): kernel suspend and resume, step by step
+ [wakeup_count.md](wakeup_count.md): the handshake `system_suspend` does before each suspend
+ [regulators.md](regulators.md): RK809 rails and `regulator-state-mem`
+ [../../Android/AOSP_cfg/sleep_flow.md](../../Android/AOSP_cfg/sleep_flow.md): from screen off to `/sys/power/state` on Android
+ [../../Android/AOSP_cfg/power_saving.md](../../Android/AOSP_cfg/power_saving.md): sleep states, s2idle vs. deep in general, Doze
+ [../../Android/AOSP_cfg/shutdown_flow.md](../../Android/AOSP_cfg/shutdown_flow.md): power-off through the RK809
+ [../../Android/HW/input_key_flow.md](../../Android/HW/input_key_flow.md): `gpio-keys`, `wakeup-source`, `WAKE` key flag
+ [../../Android/Debug/uart_console.md](../../Android/Debug/uart_console.md): UART console on RK3566

## Reference

+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
+ [System suspend code flows (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/suspend-flows.html)
+ [Device power management basics (docs.kernel.org)](https://docs.kernel.org/driver-api/pm/devices.html)
+ [Power management (source.android.com)](https://source.android.com/docs/core/power)
