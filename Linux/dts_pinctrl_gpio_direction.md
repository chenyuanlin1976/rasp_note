# Device tree pinctrl for a GPIO, and who sets its direction

A pinctrl entry with `RK_FUNC_GPIO` only muxes a pin as a GPIO and sets its electrical config (pull, drive strength).
It doesn't make the pin an input or an output.
This note walks through a Rockchip headphone-detect pin, then shows where the direction is really set:
in the driver (gpiod API), in a `gpio-hog`, or from user space.

## 1. Example: headphone-detect pin

```dts
#include <dt-bindings/pinctrl/rockchip.h>

&pinctrl {
    headphone {
        hp_det: hp-det {
            rockchip,pins = <3 RK_PA1 RK_FUNC_GPIO &pcfg_pull_down>;
        };
    };
};
```

| Part | Meaning |
| --- | --- |
| `&pinctrl { ... };` | Adds nodes to the SoC's pin controller node, which is defined in the SoC `.dtsi` |
| `headphone { ... };` | Grouping node chosen by the board designer. It has no meaning to the kernel |
| `hp_det:` | Label. Other nodes reference this pin group as `&hp_det` |
| `hp-det` | Node name of the pin group |
| `3` | GPIO bank 3 |
| `RK_PA1` | Group A, pin 1 of the bank. Pin number = group*8 + n (A=0..D=3), so 1 |
| `RK_FUNC_GPIO` | Mux 0: the pin is a plain GPIO, not UART, I2C, ... |
| `&pcfg_pull_down` | Config node from the SoC `.dtsi`: enable the internal pull-down |

The pin is **GPIO3_A1**: `gpiochip3`, line offset 1. In a `-gpios` property it's `<&gpio3 RK_PA1 ...>`.

A pin group alone does nothing. It's applied only when something references it:

+ a consumer node's `pinctrl-0` (section 4), applied by the driver core before that driver's `probe()`
+ or a pinctrl hog (`pinctrl-names`/`pinctrl-0` in the pin controller node itself), for pins no driver owns

Rockchip's GPIO driver also switches the mux to GPIO when a line is requested, but pull and drive settings come only from pinctrl.
See [dts_provider_consumer.md](dts_provider_consumer.md) for the pinctrl binding in general.

## 2. Why a pull-down for headphone detection

A headphone jack usually has a small mechanical switch that changes state when a plug is inserted.
Without a pull resistor the detect pin floats when the switch is open and picks up noise.

With `&pcfg_pull_down` the pin reads LOW when nothing is plugged in.
If the switch connects the pin to the supply on insertion, the pin goes HIGH, so "plugged in" is active-high.

The pull must match the jack wiring in the schematic:

| Switch connects the pin to | Pull | GPIO flag in the consumer |
| --- | --- | --- |
| Supply (VCC) on insertion | `&pcfg_pull_down` | `GPIO_ACTIVE_HIGH` |
| GND on insertion | `&pcfg_pull_up` | `GPIO_ACTIVE_LOW` |

Some jacks open the switch on insertion instead (normally-closed). Then the polarity flips again.

## 3. Who decides input or output

Pinctrl sets **function** and **electrical config**. The **direction** is set by whoever requests the line:

| Who | How | Typical use |
| --- | --- | --- |
| Kernel driver | `devm_gpiod_get(dev, "name", GPIOD_IN / GPIOD_OUT_LOW / ...)` (section 5) | Detect pins, buttons, reset/enable lines |
| `gpio-hog` in the device tree | `input;` / `output-low;` / `output-high;` | A fixed level at boot that nothing changes |
| User space | libgpiod on `/dev/gpiochipN` ([libgpiod_intro.md](libgpiod_intro.md)) | Pins no kernel driver owns |

The schematic tells you which one is needed:

+ **Input**: the pin receives a signal (button, switch, sensor data line, interrupt line, jack detect).
+ **Output**: the SoC drives something (LED, regulator enable, chip reset).

Generic pin config also has `input-enable`, `output-high` and `output-low` properties, and some SoC `.dtsi` files define matching config nodes.
For a pin that a driver or user space requests, leave the direction to them.

### 3.1 gpio-hog

A hog is a **child of the GPIO controller node** (not of `&pinctrl`) with the `gpio-hog` property.
Because the parent is the controller, `gpios` has no `&gpioN` phandle, only the `#gpio-cells` arguments:

```dts
&gpio3 {
    pwr-en-hog {
        gpio-hog;
        gpios = <RK_PC2 GPIO_ACTIVE_HIGH>;   /* GPIO3_C2 */
        output-high;                          /* or output-low; or input; */
        line-name = "pwr-en";
    };
};
```

The hog claims the line at boot and holds it, so a driver or user space requesting it later gets `EBUSY`.
If something should change the level at run time, don't hog the pin.
A power rail switched by a GPIO is better described as `regulator-fixed` ([dts_node_regulator_fixed.md](dts_node_regulator_fixed.md)).

## 4. Connecting the pin group to a consumer

The consumer node references both the pin group (mux + pull) and the GPIO line (for the driver):

```dts
&codec {
    pinctrl-names = "default";
    pinctrl-0 = <&hp_det>;                            /* mux + pull-down from section 1 */
    hp-det-gpios = <&gpio3 RK_PA1 GPIO_ACTIVE_HIGH>;  /* the same pin, as a GPIO for the driver */
};
```

The property name (`hp-det-gpios` here) is defined by the consumer's binding, so check the binding of the actual codec or sound-card driver.
The driver asks for it by the prefix: `"hp-det"`.

## 5. Driver side: the GPIO descriptor API (gpiod)

The driver requests the line in `probe()` and sets its direction with the flags argument.

| Flag | Direction | Initial value |
| --- | --- | --- |
| `GPIOD_IN` | Input | - |
| `GPIOD_OUT_LOW` | Output | Logical 0 |
| `GPIOD_OUT_HIGH` | Output | Logical 1 |
| `GPIOD_ASIS` | Unchanged | - (set later with `gpiod_direction_input()` / `gpiod_direction_output()`) |

Values in the gpiod API are **logical**: the `GPIO_ACTIVE_LOW` flag from the device tree inverts them.
Logical 1 means "asserted", which is a LOW physical level on an active-low line.

### 5.1 Output: enable or reset line

```dts
my_device {
    power-gpios = <&gpio3 RK_PC2 GPIO_ACTIVE_HIGH>;
};
```

```c
struct gpio_desc *power_gpio;

/* In probe(): "power" finds the power-gpios property.
 * GPIOD_OUT_LOW: make it an output, starting deasserted (logical 0). */
power_gpio = devm_gpiod_get(dev, "power", GPIOD_OUT_LOW);
if (IS_ERR(power_gpio))
	return PTR_ERR(power_gpio);   /* missing property, or -EPROBE_DEFER */

/* Later: */
gpiod_set_value(power_gpio, 1);   /* assert: HIGH, because the line is active-high */
gpiod_set_value(power_gpio, 0);   /* deassert: LOW */
```

### 5.2 Input: detect line

```dts
my_device {
    det-gpios = <&gpio3 RK_PA1 GPIO_ACTIVE_HIGH>;
};
```

```c
struct gpio_desc *det_gpio;

/* In probe(): "det" finds the det-gpios property. */
det_gpio = devm_gpiod_get(dev, "det", GPIOD_IN);
if (IS_ERR(det_gpio))
	return PTR_ERR(det_gpio);

/* Later: */
if (gpiod_get_value(det_gpio)) {
	/* asserted: headphone plugged in */
} else {
	/* deasserted: nothing plugged in */
}
```

+ To react to insert/remove events instead of polling, get the IRQ with `gpiod_to_irq()` and request it for both edges, usually with debouncing.
+ If the GPIO controller can sleep (for example an I2C GPIO expander), use `gpiod_get_value_cansleep()` / `gpiod_set_value_cansleep()`.
+ Use `devm_gpiod_get_optional()` when the property may be absent. It returns `NULL` instead of an error.

## 6. Summary

| Layer | Says |
| --- | --- |
| pinctrl group (`rockchip,pins`) | Which function the pin has (GPIO) and its pull/drive config |
| Consumer node (`pinctrl-0`, `<name>-gpios`) | Which pin group to apply, and which GPIO line the driver gets under which name and polarity |
| Driver (`devm_gpiod_get(..., flags)`) | Direction and initial value |
| `gpio-hog` | Direction and fixed value, when no driver or user space uses the pin |

## Related notes

+ [dts_provider_consumer.md](dts_provider_consumer.md): provider/consumer pattern, pinctrl states and bindings
+ [dts_node_led_vs_gpio.md](dts_node_led_vs_gpio.md): the same pin as a `gpio-leds` LED or as a plain GPIO
+ [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md): GPIO-switched power rails
+ [dts_driver_probe.md](dts_driver_probe.md): how a driver reads its node in `probe()`
+ [libgpiod_intro.md](libgpiod_intro.md): direction from user space
+ [../Android/HW/gpio_kernel_config.md](../Android/HW/gpio_kernel_config.md): pinctrl hog for a GPIO used from Android user space
+ [../Android/HW/input_key_flow.md](../Android/HW/input_key_flow.md): a `gpio-keys` input pin

## Reference

+ [Pinctrl subsystem (kernel docs)](https://docs.kernel.org/driver-api/pin-control.html)
+ [GPIO descriptor consumer interface (kernel docs)](https://docs.kernel.org/driver-api/gpio/consumer.html)
+ [GPIO mappings: device tree (kernel docs)](https://docs.kernel.org/driver-api/gpio/board.html)
+ [Rockchip pinctrl binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/pinctrl/rockchip,pinctrl.yaml)
+ GPIO bindings including `gpio-hog`: `Documentation/devicetree/bindings/gpio/` in the kernel tree
