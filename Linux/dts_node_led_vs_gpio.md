# Device tree: a pin as an LED (`gpio-leds`) vs a plain GPIO (RK3566)

A pin wired to an LED can be described in 2 ways.
The choice decides **which kernel subsystem owns the pin**, and therefore how user space and Android services control it.

| | LED (`gpio-leds`) | Plain GPIO |
| --- | --- | --- |
| Kernel owner | `leds-gpio` driver (LED class) | Nobody: free for user space |
| User-space interface | `/sys/class/leds/<name>/` (`brightness`, `trigger`) | `/dev/gpiochipN` through libgpiod |
| Blinking / heartbeat | Kernel triggers (`timer`, `heartbeat`, ...); no process needed | Your own process with a timer |
| Polarity | From the DT flag (`GPIO_ACTIVE_LOW`) | Set per request in user space |
| Best for | Status, power, and activity LEDs | Relays, enables, signals that a user-space HAL owns |

**Recommendation**: if the component is an LED, declare it as **`gpio-leds`** (or `pwm-leds` if it's on a PWM channel).
You get triggers, a stable sysfs name, and no custom code for blinking.

## 1. As an LED: `gpio-leds`

```dts
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/leds/common.h>
#include <dt-bindings/pinctrl/rockchip.h>

/ {
    leds: leds {
        compatible = "gpio-leds";
        pinctrl-names = "default";
        pinctrl-0 = <&led_pins>;                     /* mux the pins as GPIO, set pulls */

        led-0 {
            label = "sys_led_r";                     /* -> /sys/class/leds/sys_led_r */
            gpios = <&gpio4 RK_PD5 GPIO_ACTIVE_HIGH>;
            default-state = "off";                   /* "on" | "off" | "keep" */
            linux,default-trigger = "heartbeat";     /* optional: "timer", "default-on", "mmc0", ... */
        };

        led-1 {
            color = <LED_COLOR_ID_GREEN>;            /* newer style instead of label: */
            function = LED_FUNCTION_STATUS;          /* name becomes "green:status" */
            gpios = <&gpio0 RK_PC0 GPIO_ACTIVE_LOW>; /* LED lights when the pin is LOW */
        };
    };
};

&pinctrl {
    leds {
        led_pins: led-pins {
            rockchip,pins = <4 RK_PD5 RK_FUNC_GPIO &pcfg_pull_none>,
                            <0 RK_PC0 RK_FUNC_GPIO &pcfg_pull_none>;
        };
    };
};
```

+ The container node (`leds`) isn't a hardware controller. It's a node that the `leds-gpio` driver binds to,
  and each child (`led-*`) is one LED.
  The label `leds:` is only needed if another file wants to extend it with `&leds { ... }`.
+ Child node names should be `led-<n>` or `led-<name>` (dashes, no underscores; see [dts_coding_style.md](dts_coding_style.md)).
  The sysfs name comes from `label`, or from `color`/`function`.
+ Kernel config: `CONFIG_LEDS_GPIO`, plus `CONFIG_LEDS_TRIGGER_*` for each trigger you use.

### Blinking

`gpio-leds` has **no** `delay-on`/`delay-off` properties. You have these options:

+ `linux,default-trigger = "timer";` blinks at the default rate (500 ms on / 500 ms off) from boot.
+ Set custom delays at runtime, after the timer trigger is active:

  ```text
  # Android vendor init .rc (on Linux: a systemd unit or udev rule writing the same files)
  on boot
      write /sys/class/leds/sys_led_r/trigger timer
      write /sys/class/leds/sys_led_r/delay_on 100
      write /sys/class/leds/sys_led_r/delay_off 900
  ```

+ Use the `pattern` trigger (`led-pattern` property / `pattern` file) for arbitrary sequences.

The full list of attributes and triggers is in [sysfs_led_class.md](sysfs_led_class.md).

## 2. As a plain GPIO

If **no** driver should own the pin (a user-space daemon or Android HAL toggles it), don't put it in any `*-gpios` property.
Only give it a mux/pull configuration and, optionally, a name:

```dts
&pinctrl {
    pinctrl-names = "default";
    pinctrl-0 = <&relay_en>;            /* "hog": applied when the pin controller probes, since no consumer references it */

    my-board {
        relay_en: relay-en {
            rockchip,pins = <4 RK_PD5 RK_FUNC_GPIO &pcfg_pull_down>;
        };
    };
};

&gpio4 {
    /* one string per line, in offset order: 29 empty names (lines 0-28), then line 29 = RK_PD5 */
    gpio-line-names = "", "", "", "", "", "", "", "", "", "",
                      "", "", "", "", "", "", "", "", "", "",
                      "", "", "", "", "", "", "", "", "",
                      "RELAY_EN";
};
```

Defining a pin group alone does nothing until something references it, either a consumer's `pinctrl-0` or a hog like the one above.
Rockchip's GPIO driver also switches the mux to GPIO when the line is requested, but **pull/drive settings** come only from pinctrl.

Then control it from user space through the character device, **not** `/sys/class/gpio`, which is deprecated and often not built:

```shell
gpioinfo gpiochip4                 # line 29 "RELAY_EN" unused
gpioset gpiochip4 29=1             # libgpiod v1 (v2: gpioset -c gpiochip4 29=1)
```

With libgpiod v1, `gpioset` releases the line when it exits, so the value isn't guaranteed to stay.
Use `--mode=wait` (v1) or v2's `gpioset`, which holds the line until it's stopped, or let a daemon keep the line requested.

RK3566 pin math: `GPIO<bank>_<group><n>` → `gpiochip<bank>`, offset = group × 8 + n (A=0 … D=3), so GPIO4_D5 = `gpiochip4` line 29.
See [libgpiod_intro.md](libgpiod_intro.md) and [libgpiod_sysfs_cmp.md](libgpiod_sysfs_cmp.md).

Other choices for non-LED pins: **buttons** belong in `gpio-keys` (input events on `/dev/input/event*`, see [../Android/HW/input_key_flow.md](../Android/HW/input_key_flow.md)),
and **power rails** in `regulator-fixed` (see [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md)).

## 3. Checking the result

```shell
ls /sys/class/leds/                          # sys_led_r, green:status ?
cat /sys/class/leds/sys_led_r/trigger        # [heartbeat] marks the active trigger
gpioinfo gpiochip4 | grep -E "29:|used"      # line 29 used by "sys_led_r" (LED case) or unused (GPIO case)
cat /sys/kernel/debug/gpio                   # alternative (root, debugfs mounted; not on Android user builds)
cat /sys/kernel/debug/pinctrl/*/pinmux-pins  # which function/owner each pin has
```

If `/sys/class/leds/<name>` is missing:

+ Is the node in the live tree (`/proc/device-tree/leds/`)?
+ Is `CONFIG_LEDS_GPIO` enabled?
+ Does `dmesg | grep -i led` show a GPIO request failure? That happens when another node already uses the pin.

## Related notes

+ [sysfs_led_class.md](sysfs_led_class.md): LED class attributes and triggers
+ [HAL_DeviceTree.md](HAL_DeviceTree.md): from this node to a C++ HAL
+ [dts_provider_consumer.md](dts_provider_consumer.md): pinctrl details
+ [../Android/IPC/AIDL_ndk_led_sysfs.md](../Android/IPC/AIDL_ndk_led_sysfs.md), [../Android/HAL/HAL_libgpiod.md](../Android/HAL/HAL_libgpiod.md)
+ [../Android/HW/input_key_flow.md](../Android/HW/input_key_flow.md): a `gpio-keys` button from the kernel to an Android app

## Reference

+ [gpio-leds binding (leds-gpio.yaml)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/leds/leds-gpio.yaml)
+ [Common LED properties (common.yaml)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/leds/common.yaml)
+ [Rockchip pinctrl binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/pinctrl/rockchip,pinctrl.yaml)
