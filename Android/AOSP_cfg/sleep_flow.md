# Android sleep flow: from screen off to kernel suspend

This note follows an Android device from "the screen goes off" to "the kernel is suspended", and back.
Two steps are easy to mix up:

1. **Going to sleep** (framework): `PowerManagerService` (PMS) changes its wakefulness state from `AWAKE` to `ASLEEP` and turns the display off.
2. **Suspending** (kernel): the `system_suspend` service writes `mem` to `/sys/power/state`, but only when **no wake lock** is held.

The device can be asleep (screen off) for a long time without suspending, for example while music plays under a partial wake lock.
For the sleep states themselves (s2idle vs. deep) see [power_saving.md](power_saving.md); for the kernel steps see [suspend_resume_flow.md](../../Linux/suspend_resume_flow.md).

## 1. Overview

```text
power key / screen-off timeout / PowerManager.goToSleep()
        |
        v
PowerManagerService (system_server)
  + wakefulness AWAKE -> (DREAMING) -> DOZING -> ASLEEP
  + display off (DisplayPowerController), ACTION_SCREEN_OFF broadcast, keyguard
  + releases its "display" suspend blocker, enables autosuspend
        |
        |  still held: app PARTIAL_WAKE_LOCKs, framework or native wake locks?
        |  -> yes: CPUs keep running, screen stays off, nothing suspends
        v  -> no
system_suspend (android.system.suspend)
  + read /sys/power/wakeup_count, wait for no wake locks, write the count back,
    write "mem" to /sys/power/state
        |
        v
Linux kernel
  + freeze tasks, suspend devices, enter the mem_sleep mode (s2idle or deep)
  ... wakeup interrupt (power key, RTC alarm, modem, Wi-Fi) ...
  + resume; the event is handled under a wake lock, then suspend again
```

## 2. What starts it

+ **Power key** (short press): `PhoneWindowManager` calls `PowerManagerService.goToSleep()` with reason `power_button`.
+ **Screen-off timeout**: PMS tracks user activity. When `Settings.System.SCREEN_OFF_TIMEOUT` expires, the screen dims and then PMS either starts a screensaver dream (`DREAMING`) or goes to sleep (reason `timeout`).
+ **`PowerManager.goToSleep()`**: a hidden/system API that needs the `DEVICE_POWER` permission, so only system apps and the framework use it. Other callers: the lid switch, device admin `lockNow()`, `KEYCODE_SLEEP`.

Screen-on wake locks (`SCREEN_BRIGHT_WAKE_LOCK`, `FULL_WAKE_LOCK`, both deprecated) and `FLAG_KEEP_SCREEN_ON` count as user activity, so the timeout doesn't fire while they are held.
The power key always works, whatever is held.

A proximity sensor during a call turns the screen off through a `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, but the wakefulness stays `AWAKE`; the device doesn't go to sleep.

## 3. PowerManagerService: wakefulness

PMS keeps one wakefulness state (per display group since Android 13):

| State | Meaning | Display |
| --- | --- | --- |
| `AWAKE` | Normal use | On (maybe dimmed) |
| `DREAMING` | Screensaver dream running | On |
| `DOZING` | Doze dream (ambient / always-on display) running | Low-power `DOZE` / `DOZE_SUSPEND` |
| `ASLEEP` | Sleeping | Off |

On go-to-sleep, PMS first enters `DOZING`.
If a doze dream is configured (`config_dozeComponent`), it runs until it finishes; otherwise PMS moves on to `ASLEEP` right away.
Dreams and the doze dream are described in [dream_screensaver.md](dream_screensaver.md#1-when-a-dream-starts).

Along the way:

+ `DisplayPowerController` turns the display off (or puts it in a doze state) and the backlight off.
+ The `Notifier` sends `ACTION_SCREEN_OFF`, and the keyguard locks (immediately or after the lock timeout).
+ When the display is off, PMS releases its display suspend blocker and enables **autosuspend** in `system_suspend`.

"Asleep" is a framework state only. The CPUs are still running at this point.

## 4. Wake locks decide when the kernel suspends

A wake lock keeps the **CPU** running. Every layer has its own:

| Holder | Mechanism | Shown by |
| --- | --- | --- |
| Apps | `PowerManager.newWakeLock(PARTIAL_WAKE_LOCK, ...)` | `dumpsys power` |
| PMS | Native suspend blockers, e.g. `PowerManagerService.WakeLocks` (held while any partial wake lock exists) and `PowerManagerService.Display` | `dumpsys power`, `dumpsys suspend_control_internal` |
| Native daemons | `ISystemSuspend::acquireWakeLock()` via `libpower` (older releases wrote `/sys/power/wake_lock`) | `dumpsys suspend_control_internal` |
| Kernel drivers | Wakeup sources (`pm_stay_awake()`, `__pm_wakeup_event()`) | `/sys/kernel/debug/wakeup_sources` |

App wake locks are collected by PMS into its one native suspend blocker, so `system_suspend` sees only that.
Doze mode tells PMS to ignore most app wake locks, which is how Doze lets the kernel suspend sooner (see [power_saving.md](power_saving.md#7-android-framework-power-modes)).

While any of them is held, the screen stays off, and the system **doesn't** suspend.
Wake-lock rules for app developers are in [app_background_limits.md](../App/app_background_limits.md#3-wake-locks).

## 5. system_suspend hands over to the kernel

`system_suspend` (`system/hardware/interfaces/suspend/`, service `android.system.suspend`) runs a loop while autosuspend is enabled:

1. Read `/sys/power/wakeup_count`. The read blocks while a kernel wakeup event is still being processed.
2. Wait until no wake lock is held.
3. Write the value from step 1 back to `/sys/power/wakeup_count`.
   The write fails if a kernel wakeup event was reported since the read (including while waiting in step 2), and the attempt is dropped.
4. Write `mem` to `/sys/power/state`. The kernel suspends into the mode selected in `/sys/power/mem_sleep` (`s2idle` or `deep`).
5. When the write returns (after resume or an aborted suspend), back off briefly and start again.

Reading the count **before** waiting is what makes the handshake work: any wakeup event during the wait makes step 3 fail. Details in [wakeup_count.md](../../Linux/wakeup_count.md).

This is **opportunistic suspend**: Android suspends whenever it can and doesn't wait for a fixed idle time.
What the kernel does after step 3 is in [suspend_resume_flow.md](../../Linux/suspend_resume_flow.md).

## 6. Waking up

+ **Power key**: its GPIO or PMIC interrupt is a wakeup source. The kernel resumes, the key event reaches `PhoneWindowManager`, and it calls `PowerManagerService.wakeUp()`.
  PMS goes back to `AWAKE` and the display turns on. See [input_key_flow.md](../HW/input_key_flow.md).
+ **Other events** (RTC alarm, modem, Wi-Fi packet): the kernel resumes and the event is handled under a wake lock (for example, `AlarmManager` holds one while it delivers an alarm).
  The screen stays off. When the last wake lock is released, `system_suspend` suspends again.

A screen-off phone therefore resumes and suspends many times a minute or an hour; battery stats count the suspended time as "deep sleep".

## 7. Commands

```shell
# Framework state
adb shell dumpsys power | grep -i -E "mWakefulness|wake lock|suspend blocker"
adb shell settings get system screen_off_timeout     # ms
adb shell input keyevent KEYCODE_SLEEP               # go to sleep (KEYCODE_POWER toggles)
adb shell input keyevent KEYCODE_WAKEUP
adb shell svc power stayon usb                       # stay awake while on USB: true|false|usb|ac|wireless

# Suspend
adb shell dumpsys suspend_control_internal           # native wake locks, suspend stats (recent releases)
adb shell cat /sys/power/mem_sleep                   # s2idle [deep]
adb shell cat /sys/power/suspend_stats/success
adb shell cat /sys/kernel/debug/wakeup_sources       # root, debugfs
```

## Related notes

+ [power_saving.md](power_saving.md): s2idle vs. deep, Doze, App Standby, Battery Saver
+ [../../Linux/suspend_resume_flow.md](../../Linux/suspend_resume_flow.md): kernel suspend and resume, step by step
+ [../../Linux/wakeup_count.md](../../Linux/wakeup_count.md): the wakeup_count handshake used by `system_suspend`
+ [dream_screensaver.md](dream_screensaver.md): wakefulness states, dreams, doze dream
+ [shutdown_flow.md](shutdown_flow.md): the power-off path
+ [../App/app_background_limits.md](../App/app_background_limits.md): wake locks for apps
+ [../HW/input_key_flow.md](../HW/input_key_flow.md): power key and `wakeup-source`

## Reference

+ [Power management (source.android.com)](https://source.android.com/docs/core/power)
+ [`PowerManager`](https://developer.android.com/reference/android/os/PowerManager)
+ [Keep the device awake (developer.android.com)](https://developer.android.com/develop/background-work/background-tasks/awake)
+ [System sleep states (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/sleep-states.html)
