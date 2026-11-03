# Default time zone (AOSP)

The device time zone is the system property **`persist.sys.timezone`** (an Olson ID such as `Asia/Taipei`).
bionic's `localtime()` and the framework's `TimeZone.getDefault()` read it.
A user change, or automatic detection, writes it.
On the first boot, the value comes from a `build.prop`. If it isn't set anywhere, the device falls back to GMT/UTC.

## 1. Set the default in the product makefile

```shell
# device/<vendor>/<board>/device.mk
PRODUCT_PRODUCT_PROPERTIES += \
    persist.sys.timezone=Asia/Taipei
```

+ Use a **product** (or `PRODUCT_SYSTEM_EXT_PROPERTIES`) property list.
  The old `PRODUCT_PROPERTY_OVERRIDES` goes to **`/vendor/build.prop`**, and init checks vendor `build.prop` entries
  with `vendor_init` permissions.
  `persist.sys.timezone` is a system property (`timezone_prop`), so it can be rejected there.
  init then logs a permission error and ignores the line.
+ A `persist.*` value in `build.prop` is only the initial value.
  After the user (or auto-detection) changes it, the stored value in `/data/property` wins, so test on a wiped device.
+ There is no framework `config.xml` resource for the default time zone (a `config_timeZone` resource doesn't exist).

## 2. Automatic detection can override it

If **automatic time zone** is on (`def_auto_time_zone` is `true` in SettingsProvider's `defaults.xml`),
the time zone detector may replace the default as soon as it gets a suggestion from telephony (NITZ) or from location.
On a board without a modem or location provider, nothing suggests a zone, so the default stays.

To keep the configured zone fixed, turn off auto time zone by default with a SettingsProvider overlay
(same mechanism as in [wifi_default.md](wifi_default.md)):

```xml
<!-- device/<vendor>/<board>/overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml -->
<resources>
    <bool name="def_auto_time_zone">false</bool>
</resources>
```

## 3. Verify

```shell
adb shell getprop persist.sys.timezone                    # Asia/Taipei
adb shell date                                            # local time with +0800
adb shell cmd time_zone_detector get_time_zone_state      # TimeZoneState{mZoneId=Asia/Taipei, ...}
adb shell cmd time_zone_detector is_auto_detection_enabled
adb logcat -b all -d | grep -i 'persist.sys.timezone'    # permission errors while loading build.prop
```

Time zone detection (NITZ, location, `time_zone_detector`) and time sources (NTP, NITZ, GNSS) are in [time_detection.md](time_detection.md).

## Related notes

+ [time_detection.md](time_detection.md), [wifi_default.md](wifi_default.md), [SettingsProvider_intro.md](SettingsProvider_intro.md)
+ [adb_shell_cmds.md](adb_shell_cmds.md)

## Reference

+ [Time zone detection (AOSP)](https://source.android.com/docs/core/connect/time)
+ [Adding system properties](https://source.android.com/docs/core/architecture/configuration/add-system-properties)
+ [`defaults.xml` (SettingsProvider)](https://android.googlesource.com/platform/frameworks/base/+/main/packages/SettingsProvider/res/values/defaults.xml)
