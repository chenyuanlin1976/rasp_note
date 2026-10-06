# make WiFi default On

To make Wi-Fi default on when compiling AOSP, you need to modify the `overlay configuration` or `framework resource defaults`  
that dictate the initial Wi-Fi state during first boot.

Depending on your target device and AOSP version, you can achieve this using one of the following methods.

## Method 1: Modify config.xml via Device Overlay (Recommended)

The standard way to change default hardware states in AOSP is by overriding framework configurations in your device's overlay.

1. Locate or create your device's overlay configuration file, typically found at:  
   `device/<vendor>/<board>/overlay/frameworks/base/core/res/res/values/config.xml`
2. Add or modify the boolean resource for default Wi-Fi state:

```xml
<resources>
    <!-- True to make Wi-Fi default on -->
    <bool name="config_default_wifi_enabled">true</bool>
</resources>
```

3. Verification: After compiling and flashing the build, check if Wi-Fi is enabled upon first boot by running:  
   `adb shell settings get global wifi_on` (it should return 1).

## Method 2: Modify Default Settings Provider Values

If your target uses a default database configuration for system settings rather than framework overlays,  
you can change the default global setting value in the source code.

1. Locate the default settings provider values file:  
   `frameworks/base/packages/SettingsProvider/res/values/defaults.xml`
2. Find or add the def_wifi_on integer configuration:  

```xml
<resources>
    <!-- Set default Wi-Fi state: 1 for on, 0 for off -->
    <integer name="def_wifi_on">1</integer>
</resources>
```

3. Rebuild the SettingsProvider module or perform a clean build:  
   `make SettingsProvider`
