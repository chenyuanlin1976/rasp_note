# /sys/power/wakeup_count: suspending without losing wakeup events

`/sys/power/wakeup_count` lets user space start a system suspend without racing against wakeup events.
A suspend manager reads it, decides to suspend, writes the value back, and only then writes to `/sys/power/state`.
If a wakeup event is reported anywhere in between, the write or the suspend fails, and the event is handled instead of being slept through.

Android's `system_suspend` service uses it before every suspend (see [sleep_flow.md](../../Android/AOSP_cfg/sleep_flow.md#5-system_suspend-hands-over-to-the-kernel)).

## 1. Wakeup events and wakeup sources

The value is the number of **wakeup events** the kernel has registered since boot.
A wakeup event is something a driver reports as important enough to keep the system awake: a key press, a modem message, an RTC alarm, a USB plug-in.
Drivers report them through **wakeup sources**:

+ `pm_wakeup_event(dev, ms)` / `__pm_wakeup_event(ws, ms)`: an event that is processed within `ms` milliseconds.
+ `pm_stay_awake(dev)` ... `pm_relax(dev)`: an event in progress until `pm_relax()`.

The counter goes up when an event **finishes** processing. Not every interrupt counts: only events that a driver reports through a wakeup source.
Each wakeup source's statistics are in `/sys/class/wakeup/` (kernel 5.4+) and `/sys/kernel/debug/wakeup_sources`.
Arming a device as a wakeup source for suspend (`wakeup-source`, `device_init_wakeup()`) is described in [suspend_resume_flow.md](suspend_resume_flow.md#4-wakeup-and-resume).

## 2. The race it prevents

Without `wakeup_count`, a suspend manager does this:

1. Check that nothing needs the system (no wake locks, no pending work).
2. Write `mem` to `/sys/power/state`.

A wakeup event can arrive between step 1 and the moment the kernel freezes tasks.
The process that should handle it (for example, the input reader for a key press) is then frozen, and the system suspends with the event unhandled.
It is processed only at the next, unrelated wakeup, so the device seems to ignore the key press or the alarm.

## 3. The handshake

```text
user space                                  kernel
----------                                  ------
read  /sys/power/wakeup_count  ---------->  blocks while any event is in progress,
                                            then returns the count, e.g. 42
check wake locks / decide to suspend
write 42 to /sys/power/wakeup_count  ---->  count still 42 and nothing in progress?
                                              yes: save 42, start watching for new events
                                              no:  write fails (EINVAL) -> back to the read
write mem to /sys/power/state  ---------->  suspend; aborted (EBUSY) if any event was
                                            reported since the saved count
```

1. **Read**: returns the current count. If a wakeup event is still in progress (a `pm_stay_awake()` without `pm_relax()`), the read **blocks** until it finishes; a signal interrupts it (`EINTR`).
2. **Decide**: user space checks its own conditions. Android's `system_suspend` waits here until no wake lock is held.
3. **Write back**: succeeds only if the count hasn't changed and no event is in progress; otherwise it fails with `EINVAL`.
   A successful write does **not** suspend. It makes the kernel remember the count and check it during the next suspend.
4. **Suspend**: write `mem` (or `freeze`) to `/sys/power/state`.
   During the suspend, the kernel calls `pm_wakeup_pending()` at several points (after freezing tasks, after suspending devices). If any wakeup event was reported since step 3, the suspend is aborted, the write returns `EBUSY`, and user space starts over.

So the window covered by the check is the whole path from the **read** to the moment the system is suspended, not only the gap between read and write.

## 4. Rules and edge cases

+ The check is optional. Writing to `/sys/power/state` without writing `wakeup_count` first still suspends; then only wakeup interrupts that arrive during the suspend itself abort it.
+ Writes to `wakeup_count` fail with `EBUSY` while the kernel's own autosleep is active (`/sys/power/autosleep`, `CONFIG_PM_AUTOSLEEP`). Autosleep does the same handshake inside the kernel.
+ Do the read and write again before each suspend. The event that woke the system already changed the count, so an old saved value would abort the next attempt.
+ Suspend managers loop: read, wait, write, suspend, and after a failure or resume, back off briefly and repeat.

## 5. Example

```shell
# Manual suspend with the handshake (root)
count=$(cat /sys/power/wakeup_count)        # may block while an event is in progress
# ... check that nothing needs the system ...
if echo "$count" > /sys/power/wakeup_count; then
    echo mem > /sys/power/state || echo "suspend aborted by a wakeup event"
else
    echo "wakeup event since the read, not suspending"
fi

# Which wakeup sources are active or fire often
ls /sys/class/wakeup/
cat /sys/kernel/debug/wakeup_sources
cat /sys/power/suspend_stats/fail
```

## Related notes

+ [suspend_resume_flow.md](suspend_resume_flow.md): what the kernel does after the write to `/sys/power/state`
+ [../../Android/AOSP_cfg/sleep_flow.md](../../Android/AOSP_cfg/sleep_flow.md): `system_suspend` and wake locks on Android
+ [../../Android/AOSP_cfg/power_saving.md](../../Android/AOSP_cfg/power_saving.md): sleep states, s2idle vs. deep
+ [../HW/sysfs_intro.md](../HW/sysfs_intro.md): `/sys/power/`

## Reference

+ [sysfs-power ABI: /sys/power/wakeup_count (docs.kernel.org)](https://docs.kernel.org/admin-guide/abi-testing.html)
+ [System suspend code flows (docs.kernel.org)](https://docs.kernel.org/admin-guide/pm/suspend-flows.html)
+ [Device power management basics (docs.kernel.org)](https://docs.kernel.org/driver-api/pm/devices.html)
