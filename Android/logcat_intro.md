# logcat

`logcat` reads the device logs that `logd` keeps in RAM ring buffers.
Run it on the host as `adb logcat ...`, which is the same as `adb shell logcat ...` but without a tty.

```text
app (android.util.Log) / native (ALOGx, liblog) ──> logd ──> buffers: main, system, crash, events, radio, kernel, ...
                                                                    │
                                                         adb logcat (filter, format)
```

## 1. Everyday commands

```shell
adb logcat                                   # follow main + system + crash (the default buffers)
adb logcat -d > log.txt                      # dump what is buffered, then exit
adb logcat -c                                # clear the default buffers ("-b all -c": every buffer)
adb logcat -T 100                            # start from the last 100 lines, then follow
adb logcat -t '11-03 09:30:00.000'           # print lines since a time, then exit
adb logcat --pid=$(adb shell pidof -s com.example.app)   # one process
adb logcat -e 'FATAL|ANR'                    # message matches a regex
adb logcat -v color                          # colored by priority (with the default threadtime format)
adb logcat -g                                # buffer sizes; "-G 16M" to change them
```

+ `pidof` changes after the app restarts. Android Studio's Logcat window follows the package across restarts.
+ To save on the device instead: `adb shell logcat -f /data/local/tmp/log.txt -r 1024 -n 4` (1 MiB files, 4 rotations).

## 2. Priorities and filters

| Letter | Priority |
| --- | --- |
| `V` | Verbose (lowest) |
| `D` | Debug |
| `I` | Info |
| `W` | Warning |
| `E` | Error |
| `F` | Fatal (assert, `Log.wtf`) |
| `S` | Silent: filter-only, nothing is logged at this level |

A filter is `<tag>:<min_priority>`. The filters together form an allowlist when you finish with `*:S`:

```shell
adb logcat ActivityManager:I MyApp:D '*:S'   # only these 2 tags
adb logcat -s MyApp                          # shortcut: "-s" sets *:S, so this means "MyApp:V *:S"
adb logcat -s MyApp:D AndroidRuntime:E
adb logcat '*:E'                             # every tag, errors and above
```

Quote `*:S` and `*:E` on the host, so the shell doesn't expand the `*`.

The app side can also be filtered: `adb shell setprop log.tag.MyApp D` makes `Log.isLoggable("MyApp", ...)`
return `false` below Debug, and `liblog` drops those messages before they reach `logd`.

## 3. Buffers

| Buffer | Content |
| --- | --- |
| `main` | App logs (`android.util.Log`), most native logs |
| `system` | Framework / system process logs (`Slog`) |
| `crash` | Crashes: Java `FATAL EXCEPTION` (AndroidRuntime) and native crash dumps (`DEBUG`, written by `crash_dump`) |
| `events` | Binary event logs (`am_proc_start`, `am_anr`, `am_crash`, ...), shown decoded |
| `radio` | Telephony / modem |
| `kernel` | Kernel log, if `logd` reads it (`ro.logd.kernel`, usually on userdebug/eng). Otherwise use `adb shell dmesg` |

```shell
adb logcat -b crash                          # only crashes
adb logcat -b main,system,crash,events       # several
adb logcat -b all
```

### The `--------- beginning of <buffer>` lines

logcat prints `--------- beginning of main` (or `system`, `crash`, `kernel`, ...) the **first time** it prints an entry from that buffer.
It is only a separator. It doesn't mean that a phase of boot started, or that a crash happened at that point.
`beginning of crash` just means that the crash buffer has entries, which is a hint to look at `adb logcat -b crash`.

## 4. Output format

The default format is `threadtime`:

```text
11-03 09:30:12.345  1234  1250 E MyApp   : connect failed: ECONNREFUSED
date  time          PID   TID  P tag       message
```

Other formats with `-v`: `brief`, `time`, `process`, `tag`, `raw`, `long`.
Modifiers can be combined: `-v threadtime -v uid -v year`.

## 5. Working with a saved log

```shell
awk '$5 == "E"' log.txt                      # errors (5th field = priority in threadtime)
awk '$5 ~ /^[EF]$/' log.txt                  # errors and fatals
grep -n 'FATAL EXCEPTION' -A 30 log.txt      # Java crash + stack trace
grep -n -E '\bANR in\b' log.txt              # ANRs (details in /data/anr, part of the bugreport)
grep -n -E 'F DEBUG|\*\*\* \*\*\* \*\*\*' log.txt   # native crash (tombstone summary)
grep -n 'avc: denied' log.txt                # SELinux denials
```

Using fields is safer than a fixed column such as `grep -E '^.{31}E'`, which breaks when PIDs get longer than 5 digits.

## 6. When logcat isn't enough

| Need | Use |
| --- | --- |
| Everything for a bug (logs, dumpsys, tombstones, ANR traces) | `adb bugreport bugreport.zip` |
| Native crash details | `/data/tombstones/` (root), or the bugreport |
| Kernel messages | `adb shell dmesg` (root on many builds), `-b kernel` |
| Logs from before the last reboot | `adb shell cat /sys/fs/pstore/console-ramoops*` (if pstore is enabled), or `logpersist.start` on userdebug |

## Related notes

+ [adb_intro.md](adb_intro.md), [adb_shell_cmds.md](adb_shell_cmds.md)
+ [avc_denied.md](avc_denied.md): reading SELinux denials from the log

## Reference

+ [Logcat command-line tool](https://developer.android.com/tools/logcat)
+ [Understanding logging (AOSP)](https://source.android.com/docs/core/tests/debug/understanding-logging)
+ [android.util.Log](https://developer.android.com/reference/android/util/Log)
+ [Capture and read bug reports](https://developer.android.com/studio/debug/bug-report)
