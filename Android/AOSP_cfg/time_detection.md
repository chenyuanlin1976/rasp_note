# Automatic time and time zone detection

Android keeps 2 separate things:

| | Time (Unix epoch, UTC) | Time zone (Olson ID, e.g. `Asia/Taipei`) |
| --- | --- | --- |
| Service (`system_server`) | `time_detector` (Android 10+) | `time_zone_detector` (Android 11+) |
| Setting | Settings → "Set time automatically" (`Settings.Global.AUTO_TIME`) | "Set time zone automatically" (`Settings.Global.AUTO_TIME_ZONE`) |
| Stored in | The kernel clock / RTC | `persist.sys.timezone` |
| Sources | NTP (network), NITZ (telephony), GNSS, external | NITZ (telephony), location (LTZP) |

NTP only gives UTC. It knows nothing about time zones.
The time zone (offset and daylight-saving rules) is applied by the OS from the zone ID and the tzdata in the time zone APEX.

## 1. Time: origins and priority

| Origin | Source | Default |
| --- | --- | --- |
| `network` | SNTP via `network_time_update_service` (server from `config_ntpServers`, default `ntp://time.android.com`) | Used |
| `telephony` | NITZ from the cellular network | Used |
| `gnss` | Time from the GNSS location provider (Android 12+) | Not used |
| `external` | A source the device maker integrates (Android 12+) | Not used |

The priority is set by the device in the framework `config.xml` overlay. The Android 12+ default puts **network before telephony**.
Android 11 and lower preferred telephony.

```xml
<!-- device overlay: frameworks/base/core/res/res/values/config.xml -->
<string-array name="config_autoTimeSourcesPriority">
    <item>network</item>
    <item>telephony</item>
</string-array>
```

+ If the best suggestion is within about 2 s of the current clock, the clock isn't changed, to avoid `ACTION_TIME_CHANGED` broadcasts.
+ Android 13 and lower used a single NTP server resource (`config_ntpServer`). Android 14+ uses the list `config_ntpServers`.
+ A board without a modem and without a network connection keeps the RTC time until NTP succeeds.

## 2. Time zone: telephony and location

+ **Telephony** (NITZ / MCC): the phone process suggests zones based on the cell network's country and NITZ offset.
+ **Location** (Android 12+): `location_time_zone_manager` runs 1 or 2 **location time zone providers** (LTZP) and turns their results into suggestions.
  This is disabled unless the device configures a provider package (`config_enablePrimaryLocationTimeZoneProvider`, ...).
+ `time_zone_detector` combines the suggestions and writes `persist.sys.timezone`.
  With no suggestion (no modem, no LTZP), the zone stays at the configured default; see [timezone_default.md](timezone_default.md).

## 3. Debug

The `cmd` output format isn't stable between releases. `cmd <service> help` lists the test commands.

```shell
adb shell cmd time_detector dump                 # origin priorities, auto on/off, suggestion history per origin
adb shell cmd network_time_update_service dump   # NTP server, last result
adb shell cmd time_zone_detector dump
adb shell cmd time_zone_detector get_time_zone_state             # TimeZoneState{mZoneId=..., mUserShouldConfirmId=...}
adb shell cmd time_zone_detector is_auto_detection_enabled
adb shell cmd time_zone_detector is_telephony_detection_supported
adb shell cmd time_zone_detector is_geo_detection_supported
adb shell cmd location_time_zone_manager dump    # LTZP mode and package (Android 12+, if supported)
adb shell dumpsys activity service com.android.phone/com.android.phone.TelephonyDebugService   # "Time zone Logs" (NITZ)
```

Example `time_detector dump` lines from a board without a modem:

```text
mEnvironment.autoOriginPriorities()=[network, telephony]
Telephony suggestion history: {Empty}
Network suggestion history: ... time.android.com/216.239.35.12:123 ...
```

## 4. Changing the time zone from code

+ Read: `java.util.TimeZone.getDefault()`, or `TimeZone.getAvailableIDs()` (a `String[]`; available since API 1).
  For new code, prefer `java.time.ZoneId.systemDefault()` / `ZoneId.getAvailableZoneIds()` (API 26+).
+ Write: `AlarmManager.setTimeZone("Asia/Taipei")` needs `android.permission.SET_TIME_ZONE`,
  which is a **signature|privileged** permission. Only system apps can hold it.
  A normal app opens the system settings instead (`Settings.ACTION_DATE_SETTINGS`).

```kotlin
// System app with SET_TIME_ZONE (declared in the manifest and allowlisted for privileged apps)
val alarmManager = getSystemService(AlarmManager::class.java)
alarmManager.setTimeZone("Asia/Taipei")
```

If automatic time zone detection is on, the detector can overwrite a zone that was set this way.

## Related notes

+ [timezone_default.md](timezone_default.md), [SettingsProvider_intro.md](SettingsProvider_intro.md), [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)

## Reference

+ [Time and time zone detection (AOSP)](https://source.android.com/docs/core/connect/time)
+ [Network time detection](https://source.android.com/docs/core/connect/time/network-time-detection)
+ [Telephony time zone detection](https://source.android.com/docs/core/connect/time/telephony-tz-detection)
+ [Location time zone detection](https://source.android.com/docs/core/connect/time/location-tz-detection)
+ [`AlarmManager.setTimeZone`](https://developer.android.com/reference/android/app/AlarmManager#setTimeZone(java.lang.String))
