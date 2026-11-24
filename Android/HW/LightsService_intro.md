# LightsService and the Lights HAL on Android 14 (RK3566)

`LightsService` (`com.android.server.lights.LightsService`) is the framework service in `system_server` that drives the device's standard lights.
It sits between the framework clients (display, battery, notifications) and the **Lights AIDL HAL** (`android.hardware.light.ILights/default`).
The HAL writes the kernel's `/sys/class/leds/...` and `/sys/class/backlight/...` nodes.

This note covers the framework side, its pitfalls, and whether a non-LED GPIO should go through it.
For the HAL interface, the sysfs writes, and the SELinux rules, see [Led_control.md](Led_control.md#11-the-standard-lights-hal).

## 1. The layers

```text
DisplayManagerService     BatteryService     NotificationManagerService     privileged app (LightsManager)
  (backlight fallback)      (battery LED)     (notification/attention LED)    (non-system lights only)
          \                      |                     |                          /
           \--------- LightsManager (local) ----------/      ILightsManager (binder "lights")
                                 |                                     |
                     system_server: LightsService  -- one LightImpl per HwLight --
                                 |
                                 |  Binder: ILights.setLightState(id, HwLightState)
                                 v
                  vendor: Lights HAL (/vendor/bin/hw/, domain hal_light_default)
                                 |
                                 |  write brightness / trigger / delay_on / delay_off
                                 v
        kernel: /sys/class/leds/<name>/        /sys/class/backlight/<name>/
                leds-gpio, leds-pwm, PMIC      pwm-backlight (MIPI-DSI / eDP / LVDS panel)
```

| Layer | What it does |
| --- | --- |
| Framework clients | `BatteryService` sets the battery light, `NotificationManagerService` the notification and attention lights. `DisplayManagerService` uses the backlight light only as a fallback (section 3.3) |
| `LightsService` | At boot it gets the HAL with `waitForDeclaredService("android.hardware.light.ILights/default")`, calls `getLights()`, and wraps each `HwLight` in a `LightImpl` (a `LogicalLight`). It publishes the local service `LightsManager` for other `system_server` services and the binder service `lights` for the `LightsManager` API |
| Lights HAL (vendor) | Maps each light `id` to a sysfs node and converts `HwLightState` (`color`, `flashMode`, `flashOnMs`, `flashOffMs`, `brightnessMode`) into writes |
| Kernel and device tree | The RK3566 `.dts` declares `gpio-leds`, `pwm-leds`, or `pwm-backlight` nodes. The drivers create the sysfs nodes |

+ The AIDL Lights HAL exists since Android 11. If no AIDL HAL is declared in the VINTF manifest, `LightsService` falls back to the deprecated HIDL `android.hardware.light@2.0`. A new Android 14 device should implement the AIDL HAL.
+ The camera flash is not a light here. The Camera HAL controls it.
+ AOSP's `hardware/interfaces/light/aidl/default` only logs. The board's HAL (from the Rockchip SDK or your own) contains the real sysfs code.

## 2. System lights vs. lights that apps can use

`LightType` has a fixed set of values. `LightsService` splits them into 2 groups:

| | System lights | Other lights |
| --- | --- | --- |
| Types | `BACKLIGHT`, `KEYBOARD`, `BUTTONS`, `BATTERY`, `NOTIFICATIONS`, `ATTENTION`, `BLUETOOTH`, `WIFI` (the old HIDL set) | Types added later, such as `MICROPHONE` |
| Who controls them | Framework policy only (battery level, notifications, display) | Privileged apps, through `android.hardware.lights.LightsManager` sessions |
| Listed by `LightsManager.getLights()` | No | Yes |

The `LightsManager` API needs `CONTROL_DEVICE_LIGHTS` (signature|privileged).
A session's request is undone when the session is closed.
For the app side, see [gpio_control.md](gpio_control.md#22-lightsmanager-android-12-api-31).

## 3. Pitfalls

### 3.1 Unchanged requests don't reach the HAL

`LightImpl.setLightLocked()` remembers the last state it sent (color, mode, on/off times, brightness mode).
If a client sends the same state again, `LightsService` doesn't call the HAL.

+ If you change a LED with `echo ... > /sys/class/leds/...` during debugging, the framework doesn't know about it.
  An identical request afterward won't restore the LED; only a different state does.
+ After a HAL restart, the HAL may also be out of sync until the next state change.

### 3.2 Several light types on one physical LED

`LightsService` treats each `HwLight` as independent.
If the HAL maps more than one type to the same LED (for example `BATTERY` and `NOTIFICATIONS` on one RGB LED, which is common on small boards), **the HAL must arbitrate**.
It keeps the latest state of each logical light and decides which one wins (usually notification over battery).
Without this, the last writer wins, and turning off the notification also turns off the charging indication.

### 3.3 Backlight brightness is 8-bit

+ `DisplayManagerService` first tries `SurfaceControl.setDisplayBrightness()`, which goes through SurfaceFlinger to the Composer HAL.
  Only if the display doesn't support it, it uses the `BACKLIGHT` light from `LightsService`.
+ On the `LightsService` path, the float brightness (`0.0`–`1.0`) is converted to an integer `0..255` and packed into `color` as gray: `0xFF000000 | (b << 16) | (b << 8) | b`.
+ The HAL must scale this to the panel's `max_brightness`.
  With `pwm-backlight`, `max_brightness` comes from the device tree (`brightness-levels`, `num-interpolated-steps`), so it can be `255`, `1023`, or anything else.
+ If the brightness feels wrong (steps, a dark range, or no full brightness), check the HAL's scaling, the DT `brightness-levels` table, and the brightness overlay (`config_screenBrightness*` in the device's framework overlay).

### 3.4 Permissions on the sysfs nodes

The HAL runs as a non-root user in `hal_light_default`. It needs:

+ DAC: `ueventd.rc` entries that give `brightness` (and `trigger`, if it blinks) to the HAL's user.
  `delay_on` / `delay_off` are created only after `trigger=timer`, so `ueventd.rc` doesn't always cover them.
+ SELinux: a `genfscon` label (`sysfs_leds` for LEDs) and `allow` rules for `hal_light_default`.

An `EACCES` or an `avc: denied` in `logcat` means one of these is missing.
The exact rules are in [Led_control.md](Led_control.md#5-why-the-app-cant-write-sysfs-itself) and [hw_control_sysfs.md](hw_control_sysfs.md).

## 4. Inspect and test

```shell
# lights reported by the HAL, their types, and the current state
adb shell dumpsys lights

# is the AIDL HAL registered?
adb shell service list | grep -i light

# kernel nodes (userdebug / eng)
adb shell ls -l /sys/class/leds/ /sys/class/backlight/
adb shell ls -lZ /sys/class/leds/*/brightness

# HAL process and its SELinux domain
adb shell ps -AZ | grep -i light
adb logcat -d | grep -iE 'light|avc'
```

## 5. Can a non-LED GPIO go through LightsService?

Technically yes.
Declare the pin in the device tree as a `gpio-leds` node, so it appears as `/sys/class/leds/<label>/brightness` (`0` / `1`).
Then let the Lights HAL report it as a `HwLight`, and switch it by changing that light's state.
But for anything other than an indicator, this is a workaround.

| Problem | Why |
| --- | --- |
| You don't control system lights | If the pin is reported as `NOTIFICATIONS` or `ATTENTION`, framework policy switches it, not your code ([notification_led.md](notification_led.md#4-driving-a-non-led-gpio-from-notifications)) |
| Limited, fixed types | There is no OEM-defined `LightType`. A privileged app can use only the non-system types through `LightsManager`, and the state is reverted when the session closes |
| Wrong semantics | The state is a color with blink times. A relay, fan, buzzer, or enable pin has none of these |
| Coupling | Battery, notification, or display policy changes can toggle unrelated hardware, and the state cache (section 3.1) hides out-of-band changes |

Better options:

| The GPIO ... | Use |
| --- | --- |
| Is a status or indicator LED | `gpio-leds` + the Lights HAL if the meaning is standard, otherwise a vendor LED HAL: [Led_control.md](Led_control.md) |
| Switches power to a device | `regulator-fixed` / `regulator-gpio` or a power-sequence node in the device tree, so the kernel driver handles it: [../../Linux/DeviceTree/dts_node_regulator_fixed.md](../../Linux/DeviceTree/dts_node_regulator_fixed.md) |
| Is general I/O for a product feature (relay, fan, reset line) | A vendor AIDL HAL with libgpiod, called through Binder by a system app or service: [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md) |
| Only needs a quick hardware check | `adb root` + `gpioset` / `gpioget` (if libgpiod tools are in the build): [libgpiod_android.md](libgpiod_android.md) |

Going through `LightsService` makes sense only when the GPIO really is an on/off indicator that should follow a standard Android event (battery, notification), and you don't want to add a new HAL.
To choose between `gpio-leds` and a plain GPIO in the device tree, see [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md).

## Related notes

+ [Led_control.md](Led_control.md): choosing between the Lights HAL, a vendor LED HAL, and sysfs; blinking in the kernel
+ [gpio_control.md](gpio_control.md): RK3566 GPIO numbering, notification LED and `LightsManager` from an app
+ [notification_led.md](notification_led.md): how `NotificationManagerService` drives the notification LED, and why it stays off
+ [../HAL/HAL_sysfsNodes.md](../HAL/HAL_sysfsNodes.md): how a Lights HAL wraps sysfs
+ [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md), [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md), [hw_control_sysfs.md](hw_control_sysfs.md)
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)

## Reference

+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
+ [`LightsManager`](https://developer.android.com/reference/android/hardware/lights/LightsManager)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
