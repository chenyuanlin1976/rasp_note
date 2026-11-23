# Why an Android board doesn't suspend: ADB, USB, and other blockers

An RK3566 board running Android 14 often never suspends while it sits on the bench with a USB cable and ADB attached.
ADB is rarely the cause by itself. The usual causes are a "stay awake" setting, the charging state (no Doze), a USB or charger driver that holds a kernel wakeup source while VBUS is present, an app or service wake lock, or a driver that fails its suspend callback.

This note is a checklist for finding the blocker.
How suspend works is described elsewhere:

+ Android side (wakefulness, wake locks, `system_suspend`): [sleep_flow.md](../AOSP_cfg/sleep_flow.md)
+ Kernel steps: [suspend_resume_flow.md](../../Linux/Power/suspend_resume_flow.md)
+ RK3566 specifics (s2idle vs. deep, PMIC, wakeup pins): [rk3566_suspend.md](../../Linux/Power/rk3566_suspend.md)

## 1. What can block suspend

| Layer | Blocker | Effect | How to see it |
| --- | --- | --- | --- |
| Settings | `stay_on_while_plugged_in` ("Stay awake" in Developer options) | Screen stays on, PMS stays `AWAKE`, nothing suspends | `settings get global stay_on_while_plugged_in` |
| Framework | App or framework wake lock (`PARTIAL_WAKE_LOCK`) | Screen off, but no suspend | `dumpsys power` |
| Framework | Device is charging, so Doze is off | App wake locks, alarms, and jobs aren't restricted; suspends are shorter and rarer | `dumpsys deviceidle` |
| Native | Native wake lock (`libpower`, `ISystemSuspend`) | No suspend | `dumpsys suspend_control_internal` |
| Kernel | Active wakeup source held by a driver (USB, charger, Wi-Fi, ...) | `system_suspend` never gets a clean `wakeup_count` handshake | `/sys/kernel/debug/wakeup_sources`, `/sys/class/wakeup/` |
| Kernel | Task that can't be frozen, or a driver's suspend callback returns an error | Suspend starts and is aborted | `/sys/power/suspend_stats/`, `dmesg` |
| Kernel | Wakeup interrupt that keeps firing | Suspend succeeds but resumes at once | `/sys/power/pm_wakeup_irq`, `wakeup_sources` |

Regulators and the PMIC don't block suspend. They decide how much current flows once the board is suspended (see [rk3566_suspend.md](../../Linux/Power/rk3566_suspend.md)).

## 2. Why a USB cable and ADB keep the board awake

+ **Stay-awake setting**: `stay_on_while_plugged_in` is a bitmask of power sources (1 AC, 2 USB, 4 wireless, 8 dock). If the current source's bit is set, PMS keeps the screen on, so the device never goes to sleep, let alone suspends. `svc power stayon` writes the same setting.
+ **No Doze while charging**: `DeviceIdleController` enters Doze only when the device is unplugged. On USB power, apps' wake locks, alarms, and jobs run without Doze limits. This doesn't block suspend by itself, but it keeps the system awake more of the time.
+ **USB and charger drivers**: some kernels hold a wakeup source while VBUS is present in device mode. Old Android kernels had an `otg-wakelock` driver for exactly this, and vendor USB PHY, OTG, or charger drivers (such as the RK817 charger in the Rockchip BSP) may do the same. The name depends on the BSP release; find it in the wakeup sources (§3, step 3) while the cable is plugged in.
+ **ADB traffic**: an open `adb shell` or `adb logcat` keeps processes busy while data flows, and the host keeps the USB bus active (no USB bus suspend) while the ADB server talks to the device. Whether that stops a system suspend depends on the USB drivers above. `adbd` itself doesn't hold a wake lock.

When the board does suspend with the cable attached, ADB over USB stops answering until it resumes. The host may list the device as `offline` for a moment.

## 3. Checklist

Do the checks with the screen off and no ADB command running, for example a minute after pressing the power key.

**Step 1: settings and framework state**

```shell
adb shell settings get global stay_on_while_plugged_in   # 0 = off
adb shell settings put global stay_on_while_plugged_in 0 # or: adb shell svc power stayon false

adb shell dumpsys power | grep -E "mWakefulness=|mStayOn=|mHolding"
adb shell dumpsys power | sed -n '/Wake Locks:/,/^$/p'
```

+ `mWakefulness=Awake` with the screen off means something keeps PMS awake; expected values after sleep are `Asleep` or `Dozing`.
+ `mStayOn=true`: the stay-awake setting is active.
+ `mHoldingWakeLockSuspendBlocker=true`: at least one partial wake lock is held. The `Wake Locks:` list shows each one with its tag, age (`ACQ=`), uid, and pid; `adb shell pm list packages -U | grep <uid>` names the app.
+ `mHoldingDisplaySuspendBlocker=true`: the display is still considered on.

**Step 2: native wake locks**

```shell
adb shell dumpsys suspend_control_internal   # native wake locks and suspend stats (recent releases)
```

**Step 3: kernel wakeup sources**

```shell
adb root                                       # userdebug/eng build
adb shell cat /sys/kernel/debug/wakeup_sources # debugfs; /d/wakeup_sources on older releases
adb shell ls /sys/class/wakeup/                # kernel 5.4+, works without debugfs
adb shell cat /sys/power/pm_wakeup_irq         # IRQ that woke or aborted the last suspend, if any
```

+ In `wakeup_sources`, a non-zero `active_since` means the source is held right now. A fast-growing `event_count` or `wakeup_count` means it fires often.
+ Run it once with the USB cable plugged in and once over the network or UART with it unplugged (§4). A source that is only active with the cable is the USB or charger blocker from §2.
+ Android 11+ doesn't mount debugfs on user builds. Use `/sys/class/wakeup/wakeup*/` there (`name`, `active_count`, `event_count`, `active_time_ms`, ...).

**Step 4: did the kernel try, and fail?**

```shell
adb shell cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
adb shell cat /sys/power/suspend_stats/last_failed_dev   # driver whose suspend callback failed
adb shell cat /sys/power/suspend_stats/last_failed_errno
adb shell cat /sys/power/suspend_stats/last_failed_step  # freeze, suspend, suspend_late, ...
adb shell dmesg | grep -i -E "PM:|suspend|freez|wakeup|abort"
```

+ `success` doesn't change: the kernel was never asked to suspend, so the blocker is in steps 1–3.
+ `fail` goes up: the kernel tried and aborted. `dmesg` names the cause, for example `Freezing of tasks failed ... tasks refusing to freeze`, `PM: Device <name> failed to suspend`, or `PM: Some devices failed to suspend, or early wake event detected`.
+ A successful cycle logs `PM: suspend entry (deep)` (or `(s2idle)`) and later `PM: suspend exit`.

**Step 5: Doze**

```shell
adb shell dumpsys deviceidle | grep -E "mState=|mLightState="
adb shell dumpsys battery unplug        # pretend to be on battery
adb shell cmd deviceidle force-idle     # enter deep Doze now
adb shell cmd deviceidle unforce
adb shell dumpsys battery reset
```

If the board suspends under forced Doze but not otherwise, an app's wake locks, alarms, or jobs are keeping it awake; find them in step 1.

## 4. Taking USB out of the test

To see whether USB is the blocker, test without the cable.

+ **UART console** (preferred): unplug USB and watch for `PM: suspend entry` / `PM: suspend exit` on the serial console. Add `no_console_suspend` to the kernel command line to keep late messages. See [uart_console.md](uart_console.md).
+ **ADB over the network**:

  ```shell
  adb tcpip 5555                  # while still on USB; restarts adbd on TCP port 5555
  adb connect <device-ip>:5555
  # unplug the USB cable, let the board sleep, wake it, reconnect
  adb shell cat /sys/power/suspend_stats/success
  ```

  The Wi-Fi or Ethernet driver is now a possible blocker or wakeup source itself, and the TCP connection stalls or drops while the board is suspended. Reconnect after wakeup and compare `suspend_stats/success` with the value from before.

Interpreting the result:

+ Suspends without the cable, not with it: a USB or charger wakeup source (or the stay-awake USB bit). On a development board that is often acceptable. If the product must suspend while on USB, fix it in the BSP driver that holds the wakeup source, not by disabling ADB.
+ Doesn't suspend either way: the blocker is a wake lock, another wakeup source, or a driver; continue with §3 and §5.

## 5. Suspending by hand to isolate a driver

```shell
adb root
adb shell "echo +20 > /sys/class/rtc/rtc0/wakealarm"   # RTC wakes the board after 20 s
adb shell "echo mem > /sys/power/state"                # better from the UART console
adb shell cat /sys/power/suspend_stats/success
```

A direct write to `/sys/power/state` skips the `wakeup_count` handshake, so Android wake locks and already-active kernel wakeup sources don't stop it (see [wakeup_count.md](../../Linux/Power/wakeup_count.md#4-rules-and-edge-cases)).
Only frozen-task failures, driver callback errors, and wakeup interrupts during the suspend can abort it.

| Result of the manual suspend | Meaning | Next step |
| --- | --- | --- |
| Suspends, and resumes on the RTC alarm or power key | Kernel and drivers are fine; Android never asks for suspend | A wake lock or wakeup source (§3, steps 1–3) |
| Write fails (for example `EBUSY`) or returns at once | Freezer or driver abort | `suspend_stats/last_failed_*`, `dmesg` |
| Suspends but resumes immediately | A wakeup interrupt keeps firing | `pm_wakeup_irq`, `/proc/interrupts`, `wakeup_sources` |

To find the step at which suspend or resume breaks, use `pm_test` and `pm_print_times` ([suspend_resume_flow.md](../../Linux/Power/suspend_resume_flow.md#6-debugging)).

## 6. Common blockers on RK3566 boards

| Blocker | Symptom | Check or fix |
| --- | --- | --- |
| Stay-awake setting | Screen never turns off on USB or AC power | `stay_on_while_plugged_in` → `0` |
| USB VBUS / OTG / charger wakeup source | Suspends only with the cable unplugged | `wakeup_sources` with and without the cable (§3, §4) |
| App or service partial wake lock | Screen off, no suspend, `mHoldingWakeLockSuspendBlocker=true` | `dumpsys power` wake lock list |
| Wi-Fi module (AP6xxx with `bcmdhd`/`rkwifi`, or `brcmfmac`) or Ethernet (`dwmac-rk`) | Frequent wakeups or aborted suspends during network traffic | Its wakeup source in `wakeup_sources`; test with Wi-Fi off or the cable out |
| Noisy GPIO, touch, or PMIC interrupt | Resumes right after suspending | `pm_wakeup_irq`, `/proc/interrupts`; check the pin's pull and `wakeup-source` in the DT |
| Driver suspend callback error | `suspend_stats/fail` goes up | `last_failed_dev`, `last_failed_errno`, `dmesg` |
| Task that doesn't freeze | `Freezing of tasks failed` in `dmesg` | The named task, often one stuck in uninterruptible sleep (`D` state) on I/O |

## Related notes

+ [../AOSP_cfg/sleep_flow.md](../AOSP_cfg/sleep_flow.md): from screen off to `/sys/power/state` on Android
+ [../AOSP_cfg/power_saving.md](../AOSP_cfg/power_saving.md): sleep states, s2idle vs. deep, Doze
+ [../AOSP_cfg/dream_screensaver.md](../AOSP_cfg/dream_screensaver.md): wakefulness states and Doze mode
+ [../../Linux/Power/rk3566_suspend.md](../../Linux/Power/rk3566_suspend.md): s2idle vs. deep, PMIC, and wakeup sources on RK3566
+ [../../Linux/Power/suspend_resume_flow.md](../../Linux/Power/suspend_resume_flow.md): kernel suspend and resume, step by step
+ [../../Linux/Power/wakeup_count.md](../../Linux/Power/wakeup_count.md): the handshake `system_suspend` does before each suspend
+ [adb_intro.md](adb_intro.md): connecting over USB and TCP
+ [adb_shell_cmds.md](adb_shell_cmds.md): `settings`, `dumpsys`, `svc power stayon`
+ [uart_console.md](uart_console.md): UART console on RK3566

## Reference

+ [Power management (source.android.com)](https://source.android.com/docs/core/power)
+ [Optimize for Doze and App Standby (developer.android.com)](https://developer.android.com/training/monitoring-device-state/doze-standby)
+ [Android Debug Bridge (developer.android.com)](https://developer.android.com/tools/adb)
+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
+ [System suspend code flows (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/suspend-flows.html)
