# Notification LED on Android 14 (RK3566)

How `NotificationManagerService` (NMS) turns a posted notification into a blinking LED through `LightsService` and the Lights AIDL HAL.
It also explains why the LED often stays off on a custom RK3566 board, and how to react to notifications with a GPIO that isn't an LED.

For the app side (`NotificationChannel.enableLights()`), see [gpio_control.md](gpio_control.md#21-notification-led-api-26).
For `LightsService` itself, see [LightsService_intro.md](LightsService_intro.md).

## 1. From notification to LED

```text
app: NotificationChannel.enableLights(true), setLightColor(...); NotificationManager.notify()
  |
  v
system_server: NotificationManagerService
  |  should this notification blink? (config, user setting, importance, DND, screen, call)
  |  pick the most recent notification that has a light
  |  mNotificationLight.setFlashing(color, LIGHT_FLASH_TIMED, onMs, offMs)   or turnOff()
  v
system_server: LightsService (LightImpl for LightsManager.LIGHT_ID_NOTIFICATIONS)
  |  Binder: ILights.setLightState(id, HwLightState{color, flashMode=TIMED, flashOnMs, flashOffMs})
  v
vendor: Lights HAL
  |  trigger=timer, delay_on, delay_off, brightness
  v
kernel: /sys/class/leds/<led>/
```

1. **The app** asks for a light on its notification channel (Android 8+). The channel's light setting is fixed when the channel is first created; to change it, the app must use a new channel ID or be reinstalled.
2. **NMS** decides whether the notification may use the light (section 2). From all such notifications it takes the most recent one and uses its color and blink times. Without explicit values, it uses the framework defaults `config_defaultNotificationColor`, `config_defaultNotificationLedOn` and `config_defaultNotificationLedOff` (in AOSP: white, 500 ms on, 2000 ms off).
3. **`LightsService`** forwards the state to the HAL. It only sends changes (see [LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)).
4. **The Lights HAL** finds the sysfs node for the light `id`. `HwLightState` has no type field: the type belongs to the `HwLight` that the HAL reported in `getLights()`.

The attention light (`LIGHT_ID_ATTENTION`) is separate. NMS uses it only if `config_useAttentionLight` is `true`.

## 2. Why the LED stays off

| Cause | What to check or change |
| --- | --- |
| The device has no notification light for NMS | `config_intrusiveNotificationLed` is `false` in AOSP. Set it to `true` in the device's framework overlay (`overlay/frameworks/base/core/res/res/values/config.xml`). If it is `false`, NMS never touches the light |
| The user setting is off | `adb shell settings get system notification_light_pulse` must be `1` |
| The HAL doesn't report a `NOTIFICATIONS` light | `adb shell dumpsys lights` must list it. Otherwise `LightsService` has nothing to forward to |
| The screen is on, or a call is active | NMS turns the light off while the screen is on or during a call. Test with the screen off |
| The channel has no light | Channel created without `enableLights(true)`, or created earlier with lights disabled |
| Importance or DND | Low-importance notifications don't blink, and a DND policy can suppress lights |
| One-color LED, HAL checks a single channel | A board often has only one GPIO or PWM LED. The HAL should treat any non-zero RGB (`(color & 0x00FFFFFF) != 0`) as on, or derive a brightness from it, instead of reading only the red byte |
| Solid instead of blinking | The HAL ignores `flashMode`. For `FlashMode.TIMED` it should set `trigger=timer` and write `delay_on` / `delay_off` ([Led_control.md](Led_control.md#3-blink-in-the-kernel-not-with-an-app-timer)) |
| Battery state overwrites it | `BATTERY` and `NOTIFICATIONS` on the same physical LED, without arbitration in the HAL ([LightsService_intro.md](LightsService_intro.md#32-several-light-types-on-one-physical-led)) |
| `EACCES` / `avc: denied` | Permissions on `brightness`, `trigger`, `delay_on`, `delay_off` ([LightsService_intro.md](LightsService_intro.md#34-permissions-on-the-sysfs-nodes)) |

The overlay value is a build-time resource. Rebuild and reflash (or update the overlay APK) after changing it.

## 3. Test

```shell
# framework config and NMS light state
adb shell cmd overlay lookup android android:bool/config_intrusiveNotificationLed
adb shell settings get system notification_light_pulse
adb shell dumpsys notification --noredact | grep -iE 'light|led'

# what LightsService knows and last sent
adb shell dumpsys lights

# post a notification from the shell, then turn the screen off
adb shell cmd notification post -t "LED test" led_test "Testing the notification light"
adb shell input keyevent KEYCODE_SLEEP
```

`cmd notification post` uses the shell's own notification channel, which may not have lights enabled.
If nothing happens, test with a small app whose channel uses `enableLights(true)` ([gpio_control.md](gpio_control.md#21-notification-led-api-26)).
To check the HAL and the LED independently of NMS, write the sysfs node directly on a userdebug build ([Led_control.md](Led_control.md#2-on-and-off)).

## 4. Driving a non-LED GPIO from notifications

NMS has no GPIO API. It only knows notification effects: sound, vibration, and the notification and attention lights.
There are 3 ways to make a notification switch a GPIO (relay, buzzer, external signal):

| Approach | How | Assessment |
| --- | --- | --- |
| A. Pretend it is the notification LED | Declare the pin as `gpio-leds`, map `LightType.NOTIFICATIONS` to it in the Lights HAL, enable `config_intrusiveNotificationLed` | No framework code, but the pin follows LED policy: only with the screen off, blinks with `TIMED`, suppressed by DND and the user setting. Fine for an indicator, wrong for anything else ([LightsService_intro.md](LightsService_intro.md#5-can-a-non-led-gpio-go-through-lightsservice)) |
| B. Patch NMS | Add an OEM hook in NMS that calls a vendor AIDL HAL | Full control, but a framework patch you must carry through every Android update. `system_server` needs SELinux access to the vendor HAL. Never give it direct access to `/dev/gpiochip*` |
| C. Notification listener + GPIO HAL (recommended) | A system app with a `NotificationListenerService` filters the notifications it cares about and calls a vendor GPIO HAL through Binder | No framework changes; the policy is in your own code, and the HAL keeps the hardware access in its own SELinux domain |

For approach C:

+ The listener needs notification access.
  For testing: `adb shell cmd notification allow_listener <package>/<listener class>`.
  In a product, pre-grant it to the system app (for example with the framework overlay `config_defaultListenerAccessPackages`).
+ The GPIO side is a vendor AIDL HAL with libgpiod: [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md).
+ If the GPIO drives something important (alarm horn, relay), don't make it depend on notifications at all.
  Let the component that creates the event call the HAL directly. Notification policy (DND, importance, rate limiting, user settings) can suppress or delay a notification.

## Related notes

+ [LightsService_intro.md](LightsService_intro.md): `LightsService`, system lights, the state cache, sysfs permissions
+ [LightsService_platform_app.md](LightsService_platform_app.md): controlling lights from a platform-signed app instead of through notifications
+ [Led_control.md](Led_control.md): Lights HAL vs. vendor LED HAL, kernel blink triggers
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): the HAL side of `setLightState()` (color, `TIMED` blinking, sysfs)
+ [gpio_control.md](gpio_control.md): notification LED and `LightsManager` from an app
+ [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md): vendor GPIO HAL for approach C
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [`NotificationChannel.enableLights()`](https://developer.android.com/reference/android/app/NotificationChannel#enableLights(boolean))
+ [`NotificationListenerService`](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [Runtime resource overlays](https://source.android.com/docs/core/runtime/rros)
