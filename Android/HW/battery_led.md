# Battery LED on Android 14 (RK3566)

How `BatteryService` turns the battery level and charging state into a battery LED through `LightsService` and the Lights AIDL HAL.
It also explains what `BatteryService` knows (logical light, ARGB color) and what it doesn't (the physical LED), and why the LED often stays off on an RK3566 board.

For `LightsService` itself, see [LightsService_intro.md](LightsService_intro.md).
The notification LED works the same way below `LightsService`: [notification_led.md](notification_led.md).

## 1. From battery update to LED

```text
kernel: charger / fuel gauge driver (power_supply class)
  |
  v
vendor: health HAL (android.hardware.health)
  |  HealthInfo{batteryLevel, batteryStatus, ...}
  v
system_server: BatteryService
  |  update(HealthInfo) -> processValuesLocked() -> mLed.updateLightsLocked()
  |  mBatteryLight.setColor(argb) / setFlashing(argb, LIGHT_FLASH_TIMED, onMs, offMs) / turnOff()
  v
system_server: LightsService (LightImpl for LightsManager.LIGHT_ID_BATTERY)
  |  Binder: ILights.setLightState(id, HwLightState{color, flashMode, flashOnMs, flashOffMs})
  v
vendor: Lights HAL
  |  brightness (one LED or R/G/B channels), trigger=timer, delay_on, delay_off
  v
kernel: /sys/class/leds/<led>/
```

1. **The health HAL** reports every battery change to `BatteryService` through a callback (`HealthServiceWrapper`). `BatteryService` doesn't read battery uevents itself; its only `UEventObserver` watches the invalid-charger switch.
2. **`BatteryService`** handles each update in `processValuesLocked()`. After sending the battery broadcasts, it calls `Led.updateLightsLocked()`, which picks a color and blink mode (section 2).
3. **`Led`** got its light at startup with `getLocalService(LightsManager.class).getLight(LightsManager.LIGHT_ID_BATTERY)`. This is the internal `com.android.server.lights.LightsManager`, not the SDK API. If the HAL reports no `BATTERY` light, the light is `null` and `updateLightsLocked()` returns at once.
4. **`LightsService`** forwards the state to the HAL. `BATTERY` is a system light with one owner, so there is nothing to arbitrate in the framework ([LightsService_intro.md](LightsService_intro.md#21-who-wins-when-several-clients-want-a-light)). Unchanged states aren't sent again ([LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)).
5. **The Lights HAL** maps the light `id` to sysfs nodes and turns the ARGB color into brightness values (section 3).

## 2. What BatteryService decides

`updateLightsLocked()` in Android 14 uses only the battery level and status:

| Level and status | LED state | Color resource |
| --- | --- | --- |
| `level < config_lowBatteryWarningLevel`, charging | Solid | `config_notificationsBatteryLowARGB` |
| `level < config_lowBatteryWarningLevel`, not charging | Blinks (`LIGHT_FLASH_TIMED`, `config_notificationsBatteryLedOn` / `LedOff`) | `config_notificationsBatteryLowARGB` |
| Charging, `level < config_notificationsBatteryNearlyFullLevel` | Solid | `config_notificationsBatteryMediumARGB` |
| Full, or charging and `level >= config_notificationsBatteryNearlyFullLevel` | Solid | `config_notificationsBatteryFullARGB` |
| Anything else (discharging, not low) | Off | |

The low-battery rows are the default behavior. `config_notificationsBatteryLowBehavior` changes them: `0` = as above, `1` = always solid, `2` = always blinking.

The resources are integers in `frameworks/base/core/res/res/values/config.xml`. Change them in the device's framework overlay (`overlay/frameworks/base/core/res/res/values/config.xml`):

| Resource | AOSP default |
| --- | --- |
| `config_notificationsBatteryLowARGB` | `0xFFFF0000` (red) |
| `config_notificationsBatteryMediumARGB` | `0xFFFFFF00` (yellow) |
| `config_notificationsBatteryFullARGB` | `0xFF00FF00` (green) |
| `config_notificationsBatteryLedOn` / `config_notificationsBatteryLedOff` | `125` / `2875` ms |
| `config_notificationsBatteryNearlyFullLevel` | `90` (%) |
| `config_notificationsBatteryLowBehavior` | `0` |
| `config_lowBatteryWarningLevel` | `20` (%), also the low-battery warning threshold |

+ There is no boolean that enables or disables the battery LED. `BatteryService` drives it whenever the HAL reports a `BATTERY` light.
+ `config_criticalBatteryWarningLevel` and `config_shutdownBatteryTemperature` are used for warnings and shutdown, not for the LED.
+ The overlay values are build-time resources. Rebuild and reflash (or update the overlay APK) after changing them.

## 3. Logical light vs. physical LED

`BatteryService` knows a logical light (`LIGHT_ID_BATTERY`) and ARGB integers from `config.xml`. It doesn't know GPIOs, PWM channels, or `/sys/class/leds/` nodes. Neither does `LightsService`.

| Layer | Knows | Doesn't know |
| --- | --- | --- |
| `BatteryService` | When the state changes, which ARGB color and blink times to request | Whether the LED can show that color, or whether it exists |
| `LightsService` | The `HwLight` list from `getLights()`, the last state sent per light | The sysfs path of a light |
| Lights HAL | Its board table: light `id` → sysfs node(s), how to turn ARGB into brightness | Battery policy |
| Kernel and device tree | `gpio-leds`, `pwm-leds`, or PMIC LED nodes and their sysfs attributes | Android light types |

So the color is only a request. What the LED shows depends on the board and the HAL:

| Hardware on the RK3566 board | What the HAL should do with the battery color |
| --- | --- |
| One single-color GPIO or PWM LED | Treat any non-zero RGB (`(color & 0x00FFFFFF) != 0`) as on, or derive one brightness from it. Reading only the red byte turns the LED off for the green "full" color |
| Separate red / green (/ blue) LEDs or PWM channels | Write each channel's byte, scaled to its `max_brightness`, to its own `brightness` node. Red + green gives the "medium" yellow |
| One LED shared with `NOTIFICATIONS` | Keep the latest state of both lights and pick the winner, usually notification over battery ([LightsService_intro.md](LightsService_intro.md#32-several-light-types-on-one-physical-led)) |
| No status LED | Don't report a `BATTERY` light. `BatteryService` then has nothing to drive |

For a single LED, use the brightest channel (as [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#4-example-a-minimal-sysfs-lights-hal-ndk-backend) does), not a luminance formula such as `(77 * r + 150 * g + 29 * b) >> 8`. With luminance, the red low-battery color gives only 77 of 255, so a PWM LED is dim exactly when it should warn.

For blinking (`FlashMode.TIMED`), the HAL sets `trigger=timer` and writes `delay_on` / `delay_off` ([Led_control.md](Led_control.md#3-blink-in-the-kernel-not-with-an-app-timer)).
How to find the board table and the sysfs node for a light `id`: [LightsService_intro.md](LightsService_intro.md#42-from-a-light-id-to-its-sysfs-node). The HAL code: [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md). A red + green pair: section 4.

## 4. Example: one BATTERY light on a red + green LED pair

A common small-board setup: 2 single-color `gpio-leds`, red and green, side by side or behind one light pipe.
The HAL reports **one** `BATTERY` light and splits its color into the 2 LEDs.

Device tree (pins are examples; `GPIO0_A3` is `gpiochip0` offset 3, `GPIO0_A4` offset 4). Pinctrl and the newer `color` / `function` naming are in [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md#1-as-an-led-gpio-leds):

```dts
/ {
    leds {
        compatible = "gpio-leds";

        led-battery-red {
            label = "battery_red";                  /* -> /sys/class/leds/battery_red */
            gpios = <&gpio0 RK_PA3 GPIO_ACTIVE_HIGH>;
            default-state = "off";
        };

        led-battery-green {
            label = "battery_green";                /* -> /sys/class/leds/battery_green */
            gpios = <&gpio0 RK_PA4 GPIO_ACTIVE_HIGH>;
            default-state = "off";
        };
    };
};
```

What `BatteryService` requests with the AOSP colors, and what the LEDs do:

| State | Requested color | Red | Green |
| --- | --- | --- | --- |
| Low, not charging | `0xFFFF0000`, `TIMED` | Blinks | Off |
| Low, charging | `0xFFFF0000` | On | Off |
| Charging | `0xFFFFFF00` | On | On (looks yellow or amber only if the light mixes) |
| Full or nearly full | `0xFF00FF00` | Off | On |
| Off | `0x00000000` | Off | Off |

HAL side, written as an extension of the example HAL in [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#4-example-a-minimal-sysfs-lights-hal-ndk-backend) (it reuses that file's `writeFile()` and the `max_brightness` read at startup):

```c++
// One HwLight (type BATTERY) backed by 2 LED class devices.
struct RgLed {
    std::string redDir = "/sys/class/leds/battery_red";
    std::string greenDir = "/sys/class/leds/battery_green";
    int redMax = 1;    // from <dir>/max_brightness: 1 for leds-gpio
    int greenMax = 1;
};

// 0..255 channel -> 0..max_brightness; any non-zero channel is on.
int scale(uint32_t channel, int maxBrightness) {
    if (channel == 0) return 0;
    return std::max(1, static_cast<int>(channel) * maxBrightness / 255);
}

// Write order from AIDL_HAL_lights.md section 3: delay_on / delay_off exist only after trigger=timer.
void applyLevel(const std::string& dir, int level, const HwLightState& state) {
    const bool blink = state.flashMode != FlashMode::NONE && state.flashOnMs > 0 &&
                       state.flashOffMs > 0;
    if (level == 0) {
        writeFile(dir + "/brightness", "0");  // also removes the trigger
    } else if (blink) {
        writeFile(dir + "/brightness", std::to_string(level));
        writeFile(dir + "/trigger", "timer");
        writeFile(dir + "/delay_on", std::to_string(state.flashOnMs));
        writeFile(dir + "/delay_off", std::to_string(state.flashOffMs));
    } else {
        writeFile(dir + "/trigger", "none");
        writeFile(dir + "/brightness", std::to_string(level));
    }
}

// Called from setLightState() for the BATTERY light's id (under the HAL's mutex).
void setBatteryLight(const RgLed& led, const HwLightState& state) {
    const uint32_t c = static_cast<uint32_t>(state.color);
    applyLevel(led.redDir, scale((c >> 16) & 0xFF, led.redMax), state);
    applyLevel(led.greenDir, scale((c >> 8) & 0xFF, led.greenMax), state);
}
```

+ Both directories need the `ueventd.rc` and SELinux entries of [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md#5-init-vintf-ueventd-selinux), and `getLights()` should report the light only if both `brightness` nodes are writable.
+ If `NOTIFICATIONS` uses the same 2 LEDs, keep both lights' last states in the HAL and write only the winner (section 3).
+ Test the nodes by hand before testing the HAL: `echo 1 > /sys/class/leds/battery_red/brightness` as root on a userdebug build ([Led_control.md](Led_control.md#2-on-and-off)).

## 5. Why the LED stays off

| Cause | What to check or change |
| --- | --- |
| The HAL doesn't report a `BATTERY` light | `adb shell dumpsys lights` must list it. Otherwise `mBatteryLight` is `null` |
| The board has no battery | Many RK3566 boards run on DC power without a charger or fuel gauge. Then the health HAL reports no real level or charging state, and the LED stays off or never changes. Check `adb shell dumpsys battery` |
| The state really means off | Discharging above the low-battery level turns the LED off (section 2) |
| The color doesn't match the LED | One-color LED and a HAL that reads only one channel (section 3) |
| Solid instead of blinking | The HAL ignores `flashMode` |
| The notification overwrites it | `BATTERY` and `NOTIFICATIONS` on one LED without arbitration in the HAL (section 3) |
| A manual sysfs write isn't undone | `LightsService` doesn't resend an unchanged state ([LightsService_intro.md](LightsService_intro.md#31-unchanged-requests-dont-reach-the-hal)) |
| `EACCES` / `avc: denied` | Permissions on `brightness`, `trigger`, `delay_on`, `delay_off` ([LightsService_intro.md](LightsService_intro.md#34-permissions-on-the-sysfs-nodes)) |

## 6. Test

```shell
# battery state from the health HAL, and the overlay values in use
adb shell dumpsys battery
adb shell cmd overlay lookup android android:integer/config_lowBatteryWarningLevel
adb shell cmd overlay lookup android android:integer/config_notificationsBatteryLowARGB

# fake each LED state, check what LightsService sent, then restore the real values
adb shell dumpsys battery unplug
adb shell dumpsys battery set level 10        # low, not charging: blinks
adb shell dumpsys lights
adb shell dumpsys battery set ac 1
adb shell dumpsys battery set status 2        # BATTERY_STATUS_CHARGING: solid low color
adb shell dumpsys battery set level 50        # charging: medium color
adb shell dumpsys battery set level 95        # nearly full: full color
adb shell dumpsys lights
adb shell dumpsys battery reset
```

Compare the `BATTERY` light's last state in `dumpsys lights` with the LED's `brightness` and `trigger` in sysfs ([LightsService_intro.md](LightsService_intro.md#42-from-a-light-id-to-its-sysfs-node)).
If `dumpsys lights` changes but the LED doesn't, the problem is in the HAL or its permissions. If `dumpsys lights` doesn't change, check that the HAL reports a `BATTERY` light.

## Related notes

+ [LightsService_intro.md](LightsService_intro.md): `LightsService`, system lights, the state cache, the id-to-sysfs mapping
+ [notification_led.md](notification_led.md): the notification LED, which often shares the physical LED with the battery light
+ [Led_control.md](Led_control.md): Lights HAL vs. vendor LED HAL, kernel blink triggers
+ [../HAL/AIDL_HAL_lights.md](../HAL/AIDL_HAL_lights.md): the HAL side of `setLightState()` (board table, color, `TIMED` blinking, sysfs, SELinux)
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [`BatteryManager`](https://developer.android.com/reference/android/os/BatteryManager)
+ [Health HAL](https://source.android.com/docs/core/perf/health)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [Runtime resource overlays](https://source.android.com/docs/core/runtime/rros)
+ [`BatteryService.java` (AOSP)](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/services/core/java/com/android/server/BatteryService.java)
