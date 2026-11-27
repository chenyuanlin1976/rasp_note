# Notification LED on Android 14 (RK3566)

The notification light is a hardware indicator LED (often RGB, on the front bezel or the board) that blinks while the screen is off to signal unread notifications.
The system owns it: an app can only request a light for its own notifications.

This note shows how `NotificationManagerService` (NMS) turns a posted notification into a blinking LED through `LightsService` and the Lights AIDL HAL.
It also explains why the LED often stays off on a custom RK3566 board, and how to react to notifications with a GPIO that isn't an LED.

For the app side (`NotificationChannel.enableLights()`), see section 1.3.
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
2. **NMS** decides whether the notification may use the light (section 2). From all such notifications it takes the most recent one and uses its light. The color is the channel's `lightColor`, or `config_defaultNotificationColor` if the channel has none. The blink times are always the framework defaults `config_defaultNotificationLedOn` and `config_defaultNotificationLedOff`, because a channel has no blink times. In AOSP the defaults are white, 500 ms on, 2000 ms off. Only apps that target API 25 or lower still use per-notification values (section 1.2).
3. **`LightsService`** forwards the state to the HAL. It only sends changes (see [LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)).
4. **The Lights HAL** finds the sysfs node for the light `id`. `HwLightState` has no type field: the type belongs to the `HwLight` that the HAL reported in `getLights()`.
   The HAL works with `LightType` (`NOTIFICATIONS`); the `LIGHT_ID_*` constants exist only in the framework.
5. **The kernel** exposes the LED as an LED class device under `/sys/class/leds/`. The RK3566 device tree declares it as `gpio-leds`, `pwm-leds`, or a node for an I2C LED controller (for example `leds-aw2013` or the `leds-lp55xx` family). An RGB LED is either 3 devices (one per color) or one multicolor device. Each device has `brightness` (`0` to `max_brightness`, which is `1` for a GPIO LED), `trigger`, and, with `trigger=timer`, `delay_on` / `delay_off` ([../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md)).

Turning the LED off takes the same path.
NMS calls `turnOff()` when the last notification with a light is dismissed, cancelled, or times out (`setTimeoutAfter()`), and also when the screen turns on.
`LightsService` sends a state with color `0` and `FlashMode.NONE`, and the HAL writes `brightness` = `0`, which also removes the `timer` trigger ([../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#3-state-updates-setlightstate)).
If another notification with a light is still active, NMS switches to that one instead of turning the LED off.

The attention light (`LIGHT_ID_ATTENTION`) is separate. NMS uses it only if `config_useAttentionLight` is `true`.

### 1.1 What a third-party app can and can't do

An ordinary app can **request** the notification light, but it can't **control** the LED.
It needs no permission for the request. `CONTROL_DEVICE_LIGHTS` and platform signing are only for `LightsManager`, and that API doesn't reach the system lights anyway ([LightsService_platform_app.md](LightsService_platform_app.md)).

| The app can | The app can't |
| --- | --- |
| Enable lights on its channel (`enableLights(true)`) when it creates it | Change the channel's light setting later, except with a new channel ID or a reinstall (section 1.2) |
| Set a color (`setLightColor()`) | Make the LED show that color. A one-color LED looks the same for every color (section 2) |
| | Choose the blink times or brightness. NMS uses the framework defaults for every channel (section 1) |
| Post notifications on that channel | Override the user (global `notification_light_pulse` setting, the channel's setting in Settings) or DND |
| | Override NMS policy: no light while the screen is on or during a call, and only the most recent notification with a light is shown |
| | Choose the LED, pin, or sysfs node. That is the Lights HAL's board table |
| | Win against the battery light if both share one physical LED. The HAL decides ([LightsService_intro.md](LightsService_intro.md#32-several-light-types-on-one-physical-led)) |

### 1.2 Per-notification lights before Android 8, channels since

Before Android 8.0 (API 26), each notification carried its own light: the `Notification` fields `ledARGB`, `ledOnMS`, `ledOffMS` with `FLAG_SHOW_LIGHTS`, or `NotificationCompat.Builder.setLights(argb, onMs, offMs)`.
Two notifications of one app could blink in different colors.
These APIs are deprecated since API 26. An app that targets API 26+ must post on a channel, and only the channel's light setting counts.

A channel's behavior is fixed once the channel exists:

+ A second `createNotificationChannel()` with the same ID changes only the name and description, and can lower the importance if the user hasn't changed it. Lights, color, sound, and vibration stay as they were.
+ The user can change or turn off the channel in **Settings > Apps > [app name] > Notifications**, and the app can't override that.
+ The only way to change the color is a new channel ID (and `deleteNotificationChannel()` for the old one).
  Re-creating a deleted channel with the same ID restores it with its old settings, and Settings shows how many channels an app has deleted.
  Don't create one channel per color. For app-defined colors, use a custom interface ([rgb_led_customer_app.md](rgb_led_customer_app.md)).

Even a correct channel only **requests** a color. Many phones have no notification LED at all (they use an always-on display or edge lighting), a one-color LED shows its own color for every request, and an OEM image may ignore light requests from third-party apps.

### 1.3 App example

Every app uses the same API, including a `priv-app` or a platform-signed app.
Installing the app in `/system/priv-app/` doesn't change the notification light; it matters only if the app needs privileged permissions for something else.
For notification access (section 1.4), a listener needs user consent or a pre-grant, not a privileged permission.

On Android 13+, an app that targets API 33+ needs the runtime permission `POST_NOTIFICATIONS`. Without it, `notify()` posts nothing.
The user grants it; a preinstalled app can have it pre-granted through the image's default-permissions XML.

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

```kotlin
class LedNotifier(private val context: Context) {

    private val nm = context.getSystemService(NotificationManager::class.java)

    init {
        // DEFAULT or higher; LOW importance doesn't blink.
        // If the channel already exists, this doesn't change its light settings (section 1.2).
        val channel = NotificationChannel(
            CHANNEL_ID, "Message alerts", NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            enableLights(true)
            lightColor = Color.GREEN
        }
        nm.createNotificationChannel(channel)
    }

    fun show(id: Int, title: String, text: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_message)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .build()
        nm.notify(id, notification)
    }

    fun clear(id: Int) = nm.cancel(id)

    companion object {
        const val CHANNEL_ID = "messages_led_green"
    }
}
```

### 1.4 Lighting the LED for other apps' notifications

The light shows only notifications that the app posted itself.
An app with a `NotificationListenerService` ([../App/notification_listener.md](../App/notification_listener.md)) can relay them. When a watched notification is posted, it posts its own notification on its own light channel (`LedNotifier.show()`). When the watched notification is removed or read, it cancels its own notification (`LedNotifier.clear()`).

+ The listener also sees its own notifications. Ignore your own package, or the relay notification triggers itself.
+ The relay notification shows up in the notification shade, and NMS policy still applies: screen off only, DND, and the user setting.
+ For app-defined colors or states that don't follow the notification policy, use a custom LED interface instead ([rgb_led_customer_app.md](rgb_led_customer_app.md)).

## 2. Why the LED stays off

| Cause | What to check or change |
| --- | --- |
| The device has no notification light for NMS | `config_intrusiveNotificationLed` is `false` in AOSP. Set it to `true` in the device's framework overlay (`overlay/frameworks/base/core/res/res/values/config.xml`). If it is `false`, NMS never touches the light |
| The user setting is off | The **Blink light** toggle in Settings > Notifications, stored as `notification_light_pulse`: `adb shell settings get system notification_light_pulse` must be `1`. Settings shows the toggle only if `config_intrusiveNotificationLed` is `true` |
| The HAL doesn't report a `NOTIFICATIONS` light | `adb shell dumpsys lights` must list it. Otherwise `LightsService` has nothing to forward to. A BSP HAL written for a board without an indicator LED often reports only `BACKLIGHT`: add the LED to the HAL's board table ([../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#21-the-board-table)) |
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
adb shell dumpsys notification --noredact | grep messages_led_green   # the channel: mLights=true, mLightColor=...

# what LightsService knows and last sent
adb shell dumpsys lights

# post a notification from the shell, then turn the screen off
adb shell cmd notification post -t "LED test" led_test "Testing the notification light"
adb shell input keyevent KEYCODE_SLEEP

# while the LED blinks: the sysfs state the HAL wrote
adb shell 'for f in /sys/class/leds/*/; do echo "$f: $(cat $f/brightness) $(grep -o "\[[^]]*\]" $f/trigger)"; done'

# denied writes show up as avc messages
adb logcat -d | grep -iE 'avc: denied|lights'
```

Then test the clear path: wake the screen, dismiss the notification, and turn the screen off again.
The LED must stay off. Waking the screen alone isn't a test, because NMS turns the light off while the screen is on anyway.

`cmd notification post` uses the shell's own notification channel, which may not have lights enabled.
If nothing happens, test with a small app whose channel uses `enableLights(true)` (section 1.3).
To check the HAL and the LED independently of NMS, write the sysfs node directly on a userdebug build ([Led_control.md](Led_control.md#2-on-and-off)).

To follow the light decision in the AOSP source, search NMS for the light code.
Newer releases move part of it to `NotificationAttentionHelper.java` in the same directory, so search both if the first one finds nothing:

```shell
cd frameworks/base/services/core/java/com/android/server/notification/
grep -n "updateLightsLocked\|mNotificationLight\|config_intrusiveNotificationLed" \
    NotificationManagerService.java NotificationAttentionHelper.java 2>/dev/null
```

## 4. Driving a non-LED GPIO from notifications

NMS has no GPIO API. It only knows notification effects: sound, vibration, and the notification and attention lights.
The same limits apply if you want an indicator that reacts to other apps' notifications: an app can't drive the light for notifications it didn't post.
There are 3 ways to make a notification switch a GPIO (relay, buzzer, external signal):

| Approach | How | Assessment |
| --- | --- | --- |
| A. Pretend it is the notification LED | Declare the pin as `gpio-leds`, map `LightType.NOTIFICATIONS` to it in the Lights HAL, enable `config_intrusiveNotificationLed` | No framework code, but the pin follows LED policy: only with the screen off, blinks with `TIMED`, suppressed by DND and the user setting. Fine for an indicator, wrong for anything else ([LightsService_intro.md](LightsService_intro.md#5-can-a-non-led-gpio-go-through-lightsservice)) |
| B. Patch NMS | Add an OEM hook in NMS that calls a vendor AIDL HAL | Full control, but a framework patch you must carry through every Android update. `system_server` needs SELinux access to the vendor HAL. Never give it direct access to `/dev/gpiochip*` |
| C. Notification listener + GPIO HAL (recommended) | A system app with a `NotificationListenerService` filters the notifications it cares about and calls a vendor GPIO HAL through Binder | No framework changes; the policy is in your own code, and the HAL keeps the hardware access in its own SELinux domain |

For approach C:

+ The listener (callbacks, filtering, granting access) is described in [../App/notification_listener.md](../App/notification_listener.md). It needs notification access.
  For testing: `adb shell cmd notification allow_listener <package>/<listener class>`.
  In a product, pre-grant it to the system app (for example with the framework overlay `config_defaultListenerAccessPackages`).
+ The GPIO side is a vendor AIDL HAL with libgpiod: [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md).
+ If the GPIO drives something important (alarm horn, relay), don't make it depend on notifications at all.
  Let the component that creates the event call the HAL directly. Notification policy (DND, importance, rate limiting, user settings) can suppress or delay a notification.

## Related notes

+ [LightsService_intro.md](LightsService_intro.md): `LightsService`, system lights, the state cache, sysfs permissions
+ [battery_led.md](battery_led.md): the battery LED, which often shares the physical LED with the notification light
+ [LightsService_platform_app.md](LightsService_platform_app.md): controlling lights from a platform-signed app instead of through notifications
+ [rgb_led_customer_app.md](rgb_led_customer_app.md): a custom RGB LED interface for a customer app's own states
+ [Led_control.md](Led_control.md): Lights HAL vs. vendor LED HAL, kernel blink triggers
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): the HAL side of `setLightState()` (color, `TIMED` blinking, sysfs)
+ [gpio_control.md](gpio_control.md): notification LED and `LightsManager` from an app
+ [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md): vendor GPIO HAL for approach C
+ [../App/notification_listener.md](../App/notification_listener.md): `NotificationListenerService` for approach C
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [`NotificationChannel.enableLights()`](https://developer.android.com/reference/android/app/NotificationChannel#enableLights(boolean))
+ [`NotificationListenerService`](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [Runtime resource overlays](https://source.android.com/docs/core/runtime/rros)
