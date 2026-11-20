# Blinking two LEDs together on RK3566 (Android 14)

This note is a bring-up recipe: make two board LEDs blink at the same time with the kernel `timer` trigger, keep them in phase, debug the case where only one blinks, and stop them again.
It uses `adb shell` on a userdebug build. For the product design (Lights HAL, vendor HAL, SELinux), see [Led_control.md](Led_control.md).
For the LED class attributes and triggers, see [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md).

## 1. Options

| Method | Timing source | Phase between the 2 LEDs |
| --- | --- | --- |
| `leds-gpio` + `timer` trigger (section 3) | One kernel software timer **per LED** | Set by when each LED's timer was (re)started. Can wander slightly over a long time |
| `leds-pwm` (`pwm-leds` in the DT) | RK3566 PWM hardware (4 controllers × 4 channels, PWM0..PWM15, depending on pin muxing) | Independent channels; the LED class still blinks them with the `timer` trigger unless the driver supports hardware blinking |
| One loop that toggles both LEDs (native HAL or daemon) | One timer for both | Always in phase, at the cost of a process that wakes up on every edge |

SoC hardware timers are not assigned to LEDs from user space. A PWM channel is used for an LED only if the device tree describes it as `pwm-leds`.

For casual visual blinking, two `timer` triggers are enough. Use one loop only if the LEDs must stay exactly in phase for hours.
That loop belongs in a native vendor process, not in an app (see [Led_control.md](Led_control.md), section 3).

## 2. Check the LEDs

```shell
adb root
adb shell ls /sys/class/leds/
adb shell 'for l in /sys/class/leds/*; do echo "$l: $(cat $l/max_brightness)"; cat $l/trigger; done'
```

+ The directory names come from the DT `label` or node name (for example `dvb-rf`, `green:status`). Use the exact names below.
+ `trigger` lists all triggers, with the active one in `[brackets]`. If `timer` is missing, the kernel lacks `CONFIG_LEDS_TRIGGER_TIMER`.

## 3. Blink both LEDs

The order of the writes matters:

+ `delay_on` and `delay_off` exist only **after** `timer` is written to `trigger`. Writing them earlier fails with "No such file or directory".
+ Selecting `timer` starts blinking immediately with the default 500 ms / 500 ms.
+ Each write to `delay_on` or `delay_off` restarts that LED's blink cycle. So the **last write** to each LED sets its phase.

To keep the phase offset small, configure both LEDs first, then make the last write to both back to back:

```shell
adb shell '
L1=/sys/class/leds/<led1>
L2=/sys/class/leds/<led2>
echo timer > $L1/trigger
echo timer > $L2/trigger
echo 500 > $L1/delay_on
echo 500 > $L2/delay_on
echo 500 > $L1/delay_off
echo 500 > $L2/delay_off
'
```

Run it as one `adb shell` command, so the writes are milliseconds apart instead of one adb round trip apart.
If you configure LED 1 completely and then LED 2, LED 2 starts later by that delay. At 500 ms this is hardly visible.

Verify:

```shell
adb shell 'for l in <led1> <led2>; do cat /sys/class/leds/$l/trigger /sys/class/leds/$l/delay_on /sys/class/leds/$l/delay_off; done'
```

Both LEDs show `[timer]`, `500`, `500`, and blink at the same rhythm.

The settings are lost at reboot. For a boot default, use `linux,default-trigger` in the DT or an `on boot` block in a vendor `.rc` file (see [Led_control.md](Led_control.md), section 2).

## 4. Only one LED blinks

Check in this order (`L2=/sys/class/leds/<led2>`):

| Step | Command | Expected |
| --- | --- | --- |
| 1. Right node? | `ls -la /sys/class/leds/` | The name you used belongs to the second physical LED, not to another status LED |
| 2. Trigger active? | `cat $L2/trigger` | `[timer]`. If `echo timer` printed "Invalid argument", the trigger isn't built in |
| 3. Values set? | `cat $L2/delay_on $L2/delay_off $L2/max_brightness` | Your delays, and `max_brightness` > 0 |
| 4. Hardware works? | `echo none > $L2/trigger; cat $L2/max_brightness > $L2/brightness; echo 0 > $L2/brightness` | The LED turns on, then off. If not, check the DT GPIO, its active level, and the wiring |
| 5. Something resets it? | `dmesg \| grep -iE "led\|gpio"`, `ps -A \| grep -iE "light\|led"`, `logcat -d \| grep avc` | No Lights HAL, init script, or daemon rewrites the LED; no `avc: denied` |

Most likely causes:

+ **Wrong node name**: you wrote to an unused or different LED.
+ **Trigger rejected**: `trigger` doesn't show `[timer]` after the write.
+ **Overridden**: the Lights HAL, an `.rc` script, or a vendor daemon writes the LED right after you. Look for `[none]` or another trigger reappearing a few seconds later.

## 5. Stop blinking

```shell
adb shell 'echo none > /sys/class/leds/<led>/trigger; echo 0 > /sys/class/leds/<led>/brightness'          # off
adb shell 'L=/sys/class/leds/<led>; echo none > $L/trigger; cat $L/max_brightness > $L/brightness'        # solid on
```

Writing `0` to `brightness` alone also removes the trigger. Check after a few seconds that `trigger` still shows `[none]`, so nothing re-enabled it.

To turn off every LED class device while testing:

```shell
adb shell 'for l in /sys/class/leds/*; do echo none > $l/trigger; echo 0 > $l/brightness; done'
```

This also switches off LEDs that Android uses (for example a backlight or charging LED registered as an LED class device), until their owner writes them again.

## Related notes

+ [Led_control.md](Led_control.md): Lights HAL, vendor LED HAL, why blinking belongs in the kernel
+ [gpio_control.md](gpio_control.md): the RK3566 board's `gpio-leds` and GPIO recipes
+ [hw_control_sysfs.md](hw_control_sysfs.md): permissions on sysfs files
+ [../../Linux/HW/sysfs_led_class.md](../../Linux/HW/sysfs_led_class.md), [../../Linux/DeviceTree/dts_node_led_vs_gpio.md](../../Linux/DeviceTree/dts_node_led_vs_gpio.md)
+ [../SELinux/avc_denied.md](../SELinux/avc_denied.md)

## Reference

+ [LED handling under Linux (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
+ [LED triggers (kernel docs)](https://docs.kernel.org/leds/index.html)
+ [Lights HAL AIDL (`android.hardware.light`)](https://android.googlesource.com/platform/hardware/interfaces/+/main/light/aidl/)
