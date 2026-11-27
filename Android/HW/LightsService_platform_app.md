# Controlling lights from a platform-signed or privileged app (Android 14, RK3566)

An app can't call `LightsService` (`com.android.server.lights.LightsService`) directly.
It runs inside `system_server`, and its internal API (`com.android.server.lights.LightsManager`, `LogicalLight`) is a local service that only code in the same process can get.
Signing an app with the platform key doesn't change that, because the app still runs in its own process.

The same is true for an app installed in `/system/priv-app/` or `/system_ext/priv-app/` without the platform key.
It can be granted allowlisted privileged permissions such as `CONTROL_DEVICE_LIGHTS`, but it still runs as an ordinary app process in the `priv_app` SELinux domain.
It gets no access to `system_server` internals, system lights, or `/sys/class/leds/`.

This note explains what the platform key does give you, which path to use for which light, and how to add your own binder service in `system_server` when nothing else fits.
For `LightsService` itself (system lights, sessions, the state cache), see [LightsService_intro.md](LightsService_intro.md).

## 1. What the platform key gives an app

| With the platform key, the app ... | Notes |
| --- | --- |
| Gets framework permissions with `protectionLevel="signature"` | Without an allowlist entry |
| Gets `signature\|privileged` permissions such as `CONTROL_DEVICE_LIGHTS` | Either through the signature, or as a `priv-app` with a `privapp-permissions-*.xml` entry ([../Signing/sign_apk.md](../Signing/sign_apk.md#5-sign-an-app-with-the-aosp-platform-key)) |
| Is exempt from the hidden-API restrictions | Build it in the AOSP tree with `platform_apis: true` to compile against `@hide` classes such as `android.os.ServiceManager` |
| Can join `android.uid.system` (UID 1000) | Only with `android:sharedUserId="android.uid.system"` in the manifest. Deprecated since API 29 and far more privilege than LED control needs ([../Signing/sharedUserId.md](../Signing/sharedUserId.md)) |

| Even with the platform key, the app can't ... | Why |
| --- | --- |
| Call `LocalServices.getService(LightsManager.class)` | Local services exist only inside `system_server` |
| Set a system light (`BATTERY`, `NOTIFICATIONS`, `ATTENTION`, `BACKLIGHT`, ...) through the binder service `lights` | `ILightsManager` (the `lights` binder) only accepts sessions for non-system lights |
| Write `/sys/class/leds/...` | DAC and SELinux decide, not the signature ([hw_control_sysfs.md](hw_control_sysfs.md)) |

To check that a platform-signed APK installed as expected:

```shell
adb install -r app-platform-signed.apk
adb shell ps -A -o USER,PID,NAME | grep com.example.ledapp      # u0_aNNN normally; system only with sharedUserId=android.uid.system
adb shell dumpsys package com.example.ledapp | grep -A1 CONTROL_DEVICE_LIGHTS   # granted=true
```

## 2. Choose the path

First check what the HAL reports. `LightsService` only knows the lights that the Lights HAL lists in `getLights()`; a board LED that the HAL doesn't map can't be reached by any framework path.

```shell
adb shell ls -l /sys/class/leds/      # kernel LED nodes (gpio-leds / pwm-leds)
adb shell dumpsys lights              # lights reported by the HAL, with id, type, and state
```

| You want to ... | Use | Framework changes |
| --- | --- | --- |
| Light up a LED when a notification arrives | A notification channel with `enableLights(true)`; NMS drives `NOTIFICATIONS` ([notification_led.md](notification_led.md)) | None, but `config_intrusiveNotificationLed` must be `true` |
| Control a non-system light (for example `MICROPHONE`) from your app | The public `android.hardware.lights.LightsManager` with `CONTROL_DEVICE_LIGHTS` ([gpio_control.md](gpio_control.md#22-lightsmanager-android-12-api-31)) | None |
| Control a product-specific indicator (status, recording, RF on), or set any RGB color from your app | A vendor LED HAL called through Binder by your system app ([Led_control.md](Led_control.md)). For a customer app signed with another key, see [rgb_led_customer_app.md](rgb_led_customer_app.md) | None; vendor HAL + SELinux |
| Override a system light (for example force the battery LED) from your app | A custom binder service in `system_server` (section 3) | A `frameworks/base` patch |

The first 3 rows cover almost every product. Section 3 is a framework patch that you must carry through every Android update, and it fights with the framework's own policy (section 3.4).

If the LED doesn't show up in `dumpsys lights`, fix the lower layers first: the `gpio-leds` / `pwm-leds` node in the device tree ([../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)) and the HAL's light table ([../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md)).

### 2.1 Do you need to change `LightsService`?

Usually not. `LightsService` already accepts requests from apps through `LightsManager` sessions, and handles their lifetime, priority, and forwarding to the HAL.

| Situation | What to change |
| --- | --- |
| The LED is reported as a non-system type, and the app holds `CONTROL_DEVICE_LIGHTS` | Nothing. Use a `LightsManager` session |
| The LED is reported as a system type (`BATTERY`, `NOTIFICATIONS`, ...) | `LightsManager.getLights()` doesn't list it. Report it as a non-system type in the HAL, use a vendor LED HAL, or add a service as in section 3 |
| The app is signed with another key, or is a third-party app | Don't relax the permission check in `LightsService`. Let a privileged system app own the session and expose a narrow Binder API ([../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)) |
| Several lights share one physical LED and need priorities | Arbitrate in the HAL ([LightsService_intro.md](LightsService_intro.md#32-several-light-types-on-one-physical-led)). Sessions already have priorities among themselves |
| The LED doesn't light up | Almost never `LightsService`. Check the HAL mapping, the device tree, and DAC/SELinux on `brightness`, `trigger`, `delay_on`, `delay_off` ([LightsService_intro.md](LightsService_intro.md#4-inspect-and-test)) |

For the first row, the app declares the permission and gets it either through the platform signature or as an allowlisted `priv-app` (section 1):

```xml
<uses-permission android:name="android.permission.CONTROL_DEVICE_LIGHTS" />
```

Then check that `lightsManager.lights` (`getLights()`) contains the target light. If it doesn't, compare with `adb shell dumpsys lights`: a light that `dumpsys` lists but `getLights()` doesn't is a system type.

## 3. A custom binder service in `system_server`

The service runs in `system_server`, gets the internal `LightsManager` as a local service, and publishes a binder that your platform-signed app calls.

```text
platform-signed app  --Binder "led_control"-->  system_server: LedControlService
                                                    |  LocalServices.getService(LightsManager.class)
                                                    v
                                                LightsService -> ILights HAL -> /sys/class/leds/<name>/
```

### 3.1 Interface

```java
// ILedControlService.aidl (example name and package)
package com.example.server.led;

interface ILedControlService {
    // lightId: LightsManager.LIGHT_ID_* ; flashMode: LogicalLight.LIGHT_FLASH_NONE / LIGHT_FLASH_TIMED
    void setLight(int lightId, int color, int flashMode, int onMs, int offMs);
    void turnOff(int lightId);
}
```

The generated stub must be available both to `services.jar` and to the app.

### 3.2 Service

```java
// frameworks/base/services/core/java/com/example/server/led/LedControlService.java (sketch)
public final class LedControlService extends SystemService {
    private LightsManager mLights;   // com.android.server.lights.LightsManager (internal)

    public LedControlService(Context context) { super(context); }

    @Override
    public void onStart() {
        mLights = LocalServices.getService(LightsManager.class);
        publishBinderService("led_control", new ILedControlService.Stub() {
            @Override
            public void setLight(int id, int color, int mode, int onMs, int offMs) {
                getContext().enforceCallingOrSelfPermission(
                        android.Manifest.permission.CONTROL_DEVICE_LIGHTS, "setLight");
                LogicalLight light = mLights.getLight(id);
                if (light != null) light.setFlashing(color, mode, onMs, offMs);
            }

            @Override
            public void turnOff(int id) {
                getContext().enforceCallingOrSelfPermission(
                        android.Manifest.permission.CONTROL_DEVICE_LIGHTS, "turnOff");
                LogicalLight light = mLights.getLight(id);
                if (light != null) light.turnOff();
            }
        });
    }
}
```

+ Start it from `SystemServer` (for example in `startOtherServices()` with `mSystemServiceManager.startService(LedControlService.class)`). `LightsService` starts earlier, so the local service exists by then.
+ Check a permission in every binder method. Reusing `CONTROL_DEVICE_LIGHTS` keeps the rule "only privileged or platform apps control lights".
+ `getLight()` returns the first light of that system type, or `null` if the HAL reports none.

### 3.3 SELinux

A new binder service name needs a `service_contexts` entry and a type, otherwise `servicemanager` refuses `addService` and `getService`:

```text
# service.te
type led_control_service, system_server_service, service_manager_type;

# service_contexts
led_control    u:object_r:led_control_service:s0

# client: the app's domain (platform_app if platform-signed, priv_app for a priv-app
# with another key, or your own domain)
allow platform_app led_control_service:service_manager find;
```

`system_server` can already add any `system_server_service`. These are platform (system-side) policy files, not vendor policy.

### 3.4 Limits

+ The light's owner still sets it. If your service sets `BATTERY`, `BatteryService` overwrites it at the next battery change; `NOTIFICATIONS` is overwritten by NMS. The last writer wins, and `LightsService` doesn't arbitrate system lights ([LightsService_intro.md](LightsService_intro.md#21-who-wins-when-several-clients-want-a-light)).
+ The state cache skips requests identical to the last one ([LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)).
+ To give your app exclusive control of a LED, don't report it as a system type. Report it as a non-system type and use `LightsManager` sessions, or use a vendor LED HAL (section 2).

### 3.5 Client and verification

In the app, built in the AOSP tree with `platform_apis: true` and `certificate: "platform"`:

```kotlin
val binder = android.os.ServiceManager.getService("led_control")   // @hide API
val led = ILedControlService.Stub.asInterface(binder)
led.setLight(LightsManager.LIGHT_ID_NOTIFICATIONS, Color.GREEN, LogicalLight.LIGHT_FLASH_TIMED, 500, 500)
```

`LIGHT_ID_*` and `LIGHT_FLASH_*` are constants of internal `system_server` classes; copy the values into the app or define them in the AIDL file.

```shell
adb shell service list | grep led_control     # led_control: [com.example.server.led.ILedControlService]
adb shell dumpsys lights                      # the light's state changed
adb logcat -d | grep -iE 'led_control|avc'    # SecurityException or SELinux denials
```

## Related notes

+ [LightsService_intro.md](LightsService_intro.md): layers, system vs. other lights, session arbitration, pitfalls
+ [notification_led.md](notification_led.md): driving the notification LED from a notification channel
+ [gpio_control.md](gpio_control.md): notification LED and `LightsManager` from an app
+ [Led_control.md](Led_control.md): Lights HAL vs. vendor LED HAL
+ [rgb_led_customer_app.md](rgb_led_customer_app.md): RGB LED interfaces for a customer app signed with its own key
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): implementing the Lights HAL on RK3566
+ [../Signing/sign_apk.md](../Signing/sign_apk.md), [../Signing/sharedUserId.md](../Signing/sharedUserId.md): platform key and `android.uid.system`
+ [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md): exposing a system service to other apps through a system app

## Reference

+ [`LightsManager`](https://developer.android.com/reference/android/hardware/lights/LightsManager)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [Restrictions on non-SDK interfaces](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces)
+ [Privileged permission allowlisting](https://source.android.com/docs/core/permissions/perms-allowlist)
+ [SELinux concepts](https://source.android.com/docs/security/features/selinux/concepts)
