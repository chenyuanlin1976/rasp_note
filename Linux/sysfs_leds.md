# LED class: controlling LEDs through sysfs

Linux controls LEDs through the **LED class** subsystem.
Every LED that a driver registers appears as a directory under **`/sys/class/leds/<name>/`**.
GPIO moved from `/sys/class/gpio` to the character device `/dev/gpiochipN`.
LEDs did **not**: sysfs is the intended, standard interface for them, and there is no `/dev` node.

## 1. Where LEDs come from

A driver registers each LED with `led_classdev_register()`. Common drivers:

+ **`leds-gpio`**: an LED on a GPIO pin, described in the device tree (`compatible = "gpio-leds"`).
  See [HAL_DeviceTree.md](HAL_DeviceTree.md) and [dts_node_leds.md](dts_node_leds.md).
+ **`leds-pwm`**: dimmable LEDs on a PWM channel (`compatible = "pwm-leds"`).
+ **PMIC / LED-controller drivers**: I2C LED drivers, keyboard backlights, RGB controllers (multicolor class).

**Name**: `devicename:color:function` (for example `platform:green:status`), or just the DT `label`.
Newer device trees use `color = <LED_COLOR_ID_GREEN>;` and `function = LED_FUNCTION_STATUS;`, and the kernel builds the name from them.

## 2. Attributes

| File | Meaning |
| --- | --- |
| `brightness` | `0` = off, `1..max_brightness` = on/level. Writing `0` also **removes the active trigger** |
| `max_brightness` | Read-only: `1` for a simple GPIO LED, often `255` for PWM LEDs |
| `trigger` | Reading lists all triggers, with the active one in `[brackets]`. Writing a name selects it |
| `delay_on`, `delay_off` | Blink times in ms; they **appear only after** `trigger` is set to `timer` |
| `brightness_hw_changed` | Only for LEDs whose brightness hardware can change (e.g. a keyboard backlight hotkey); you can `poll()` it |
| `multi_intensity`, `multi_index` | Multicolor (RGB) LEDs: per-channel intensities |

Common **triggers** (each needs its kernel config, `CONFIG_LEDS_TRIGGER_*`):

| Trigger | Behavior |
| --- | --- |
| `none` | Manual control through `brightness` |
| `default-on` | On at boot |
| `timer` | Blinks with `delay_on`/`delay_off` (handled by the kernel; no user process needed) |
| `heartbeat` | Double blink; the rate follows the system load |
| `oneshot` | One blink per write to `shot` |
| `pattern` | Arbitrary brightness/duration sequence in `pattern`, repeated `repeat` times |
| `netdev` | Link/activity of a network interface (`device_name`, `link`, `rx`, `tx`) |
| `mmc0`, `disk-activity`, `cpu`, `panic` | Activity / state indicators |

## 3. Shell examples

```shell
LED=/sys/class/leds/system_status

cat $LED/max_brightness
cat $LED/trigger                               # e.g.: [none] timer heartbeat mmc0 ...

echo none | sudo tee $LED/trigger              # manual mode
cat $LED/max_brightness | sudo tee $LED/brightness   # full on
echo 0 | sudo tee $LED/brightness              # off

echo timer | sudo tee $LED/trigger             # blink 100 ms on / 900 ms off
echo 100 | sudo tee $LED/delay_on
echo 900 | sudo tee $LED/delay_off

echo heartbeat | sudo tee $LED/trigger
```

Writing needs root by default. To give a service access, use a udev rule (`RUN+="/bin/chmod g+w /sys%p/brightness"` with `chgrp`),
or `ueventd.rc` on Android (see [../Android/HAL_sysfsNodes.md](../Android/HAL_sysfsNodes.md)).

## 4. Settings don't persist

Everything above is lost at reboot. To set the state at boot:

+ **Device tree**: `linux,default-trigger = "heartbeat";`, `default-state = "on" | "off" | "keep";` in the LED node
+ a udev rule or a small systemd service (Linux), or an `on boot` block in an init `.rc` file (Android)

## 5. Why LEDs have no `/dev` node

+ The LED class is a **high-level** interface: "brightness" and "trigger", not pins and levels.
  Each operation is one small value, which is exactly what sysfs is designed for.
+ **Triggers run in the kernel.** Blinking, heartbeat, and disk/network activity need no user-space process, and they keep working if user space crashes.
+ LEDs are outputs. There are no input events to deliver, except `brightness_hw_changed`, which supports `poll()`.

(`/dev/uleds` does exist, but it works the other way round: user space **creates** a virtual LED that kernel triggers can drive.)

## 6. If you think you need a character device

Usually you don't. Write the sysfs files from your daemon or HAL.
That is how Android's Lights HAL implementations work (see [../Android/AIDL_ndk_led_sysfs.md](../Android/AIDL_ndk_led_sysfs.md)).
If you still need another interface:

1. **A custom kernel module** that registers a `/dev/my_led` misc device and calls the in-kernel LED API
   (`led_set_brightness()`, or register an LED trigger and call `led_trigger_event()`).
   This is extra kernel code to maintain, so it's rarely worth it.
2. **Bypass the LED class** and drive the pin as a plain GPIO through `/dev/gpiochipN` (libgpiod).
   First **remove the LED from the device tree's `gpio-leds` node**: while `leds-gpio` owns the line, the request fails with `EBUSY`.
   You lose kernel triggers (blinking then needs a user-space timer) and the stable `/sys/class/leds/<name>` path.

## Related notes

+ [sysfs_intro.md](sysfs_intro.md): sysfs in general
+ [HAL_DeviceTree.md](HAL_DeviceTree.md): `gpio-leds` in the device tree, and a C++ HAL over `/sys/class/leds`
+ [dts_node_leds.md](dts_node_leds.md), [dts_conventions.md](dts_conventions.md)
+ [../Android/Led_control.md](../Android/Led_control.md): LEDs on Android (Lights HAL, vendor HAL, kernel blinking)

## Reference

+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
+ [LED triggers: timer, oneshot, pattern, netdev (kernel docs)](https://docs.kernel.org/leds/index.html)
+ `Documentation/ABI/testing/sysfs-class-led*` in the kernel source
