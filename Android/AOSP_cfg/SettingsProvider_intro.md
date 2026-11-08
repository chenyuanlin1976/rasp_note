# SettingsProvider

SettingsProvider (`frameworks/base/packages/SettingsProvider`, package `com.android.providers.settings`) is the
`ContentProvider` that stores the framework's key/value settings: screen timeout, brightness, airplane mode, location mode, and so on.
It runs inside the `system_server` process.
Apps use it through `android.provider.Settings` (`content://settings/...`), and the shell uses it through the `settings` command.

## 1. The 3 namespaces

| Namespace | Scope | Examples | Who can write |
| --- | --- | --- | --- |
| `Settings.System` | Per user | `screen_brightness`, `screen_off_timeout`, `font_scale` | Apps with the special `WRITE_SETTINGS` access (user grants it in Settings), and only for public keys |
| `Settings.Secure` | Per user | `location_mode`, `default_input_method`, `enabled_accessibility_services`, `android_id` | `WRITE_SECURE_SETTINGS` (signature/privileged; grantable to a debug app with `pm grant`) |
| `Settings.Global` (Android 4.2+) | Device-wide, all users | `airplane_mode_on`, `adb_enabled`, `wifi_on`, `stay_on_while_plugged_in` | `WRITE_SECURE_SETTINGS` |

+ Apps can read most keys, but apps targeting Android 12 (API 31) or higher can only read the keys that the SDK exposes.
  They can't read hidden ones.
+ `adb shell settings` runs as the `shell` user, which holds `WRITE_SECURE_SETTINGS`, so it can change all 3 namespaces.
  Commands: [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md#4-settings).

## 2. How it works

+ **Storage**: since Android 6.0, each namespace is an XML file per user:
  `/data/system/users/<userId>/settings_system.xml`, `settings_secure.xml`, and `settings_global.xml` (user 0 only).
  Older releases used the SQLite database `settings.db`, which is migrated on upgrade.
  Writes are batched to disk, so read values through the API or `settings get`, not from the file.
+ **Access**: `Settings.System.getInt(resolver, name)` and the similar calls go through Binder to the provider.
  The provider checks the caller's permissions per namespace and per key.
+ **Caching**: the client side (`Settings.NameValueCache`) caches values in the app's process.
  A generation counter shared with the provider tells it when a value has changed, so most reads don't cross processes.
+ **Change notifications**: register a `ContentObserver` on `Settings.Global.getUriFor(name)` (or `System` / `Secure`)
  to react when a value changes.

```kotlin
val uri = Settings.Global.getUriFor(Settings.Global.AIRPLANE_MODE_ON)
contentResolver.registerContentObserver(uri, false, object : ContentObserver(Handler(Looper.getMainLooper())) {
    override fun onChange(selfChange: Boolean) {
        val on = Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) == 1
        Log.d("Settings", "airplane mode = $on")
    }
})
```

## 3. Default values in an AOSP build

The first-boot values come from `frameworks/base/packages/SettingsProvider/res/values/defaults.xml`
(`def_screen_off_timeout`, `def_airplane_mode_on`, ...).
Change them for a device with a resource overlay, for example
`device/<vendor>/<board>/overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml`, instead of editing the framework.
Defaults apply only when the settings files are created, so test with a factory reset or a clean flash.
Example: [wifi_default.md](wifi_default.md).

## 4. Settings vs hardware

SettingsProvider stores **configuration**, for example "the user wants the notification LED to blink".
It doesn't drive hardware.
A system service reads the setting and calls a HAL, which writes to the kernel interface (such as `/sys/class/leds/`).
See [../HW/gpio_control.md](../HW/gpio_control.md) and [../HAL/AIDL_HAL_intro.md](../HAL/AIDL_HAL_intro.md).

## Related notes

+ [../Debug/adb_shell_cmds.md](../Debug/adb_shell_cmds.md), [../App/ContentProvider_sharing.md](../App/ContentProvider_sharing.md)
+ [wifi_default.md](wifi_default.md), [timezone_default.md](timezone_default.md)

## Reference

+ [`android.provider.Settings`](https://developer.android.com/reference/android/provider/Settings)
+ [`Settings.System`](https://developer.android.com/reference/android/provider/Settings.System), [`Settings.Secure`](https://developer.android.com/reference/android/provider/Settings.Secure), [`Settings.Global`](https://developer.android.com/reference/android/provider/Settings.Global)
