# change default timezone

To change the default timezone when compiling AOSP so that it is automatically set on first boot,  
you can configure the default persistent timezone property in your device's makefiles or configuration overlays.

## Set persist.sys.timezone in product makefile

Open your device's main **makefile** (usually `device/<vendor>/<board>/device.mk or product.mk`)  
and add the default property assignment:

```makefile
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.timezone=Asia/Taipei
```

+ Verification: After flashing the new build, check the property via `adb shell getprop persist.sys.timezone`  
  to ensure it returns Asia/Taipei.

## Alternatively, use a framework overlay config.xml

If your build supports framework resource overlays,  
you can specify the default timezone string resource in your device overlay file  
(`device/<vendor>/<board>/overlay/frameworks/base/core/res/res/values/config.xml`):

```xml
<resources>
    <string name="config_timeZone">Asia/Taipei</string>
</resources>
```

+ Verification: Run `date` in an adb shell after boot to verify the local time correctly incorporates the 8-hour offset.
