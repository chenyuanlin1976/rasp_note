# Make Wi-Fi on by default (AOSP)

The Wi-Fi on/off state is the global setting `wifi_on` (`Settings.Global.WIFI_ON`).
The Wi-Fi service (`packages/modules/Wifi`, `WifiSettingsStore`) reads it at boot and writes it when the user toggles Wi-Fi.
Its first-boot value comes from SettingsProvider:

```xml
<!-- frameworks/base/packages/SettingsProvider/res/values/defaults.xml (AOSP default) -->
<bool name="def_wifi_on">false</bool>
```

`DatabaseHelper` loads it with `loadBooleanSetting(stmt, Settings.Global.WIFI_ON, R.bool.def_wifi_on)` when the settings are first created.
There is no framework `config.xml` switch for this.

## 1. Override it for your device

Don't edit `frameworks/base`. Overlay the SettingsProvider resource from the device tree instead:

```xml
<!-- device/<vendor>/<board>/overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml -->
<resources>
    <bool name="def_wifi_on">true</bool>
</resources>
```

```shell
# device.mk (skip if the board already sets an overlay directory)
DEVICE_PACKAGE_OVERLAYS += device/<vendor>/<board>/overlay
```

+ With `PRODUCT_ENFORCE_RRO_TARGETS`, the build turns this static overlay into a runtime resource overlay (RRO) for `com.android.providers.settings`.
  Either way, the file path mirrors the path in the source tree.
+ The default is used **only when the settings are created**, which means the first boot after a flash with data wiped, or a factory reset.
  An existing `/data` keeps the old value.

## 2. Build and verify

```shell
m                                   # or at least: m SettingsProvider, then rebuild the images
# flash with -w (wipe data), or factory-reset
adb shell settings get global wifi_on                  # 1
adb shell cmd wifi status                              # Wi-Fi state, connection
```

## 3. If Wi-Fi still starts off

+ Check that the overlay was really applied:
  `adb shell cmd overlay list | grep -i settings` (RRO), or confirm that the build used the overlay directory.
+ Wi-Fi needs a working driver, firmware, and Wi-Fi HAL.
  `wifi_on=1` with a broken HAL shows as "enabling" and then "disabled" in `adb logcat | grep -i wifi`.
+ For a one-off change on a running device: `adb shell svc wifi enable` (or `cmd wifi set-wifi-enabled enabled`).

## Related notes

+ [SettingsProvider_intro.md](SettingsProvider_intro.md): namespaces, storage, default values
+ [timezone_default.md](timezone_default.md), [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md)

## Reference

+ [`defaults.xml` (SettingsProvider)](https://android.googlesource.com/platform/frameworks/base/+/main/packages/SettingsProvider/res/values/defaults.xml)
+ [Runtime resource overlays (RRO)](https://source.android.com/docs/core/runtime/rros)
+ [`Settings.Global.WIFI_ON`](https://developer.android.com/reference/android/provider/Settings.Global#WIFI_ON)
