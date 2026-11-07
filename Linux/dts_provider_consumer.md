# Device tree conventions: providers, consumers, and pinctrl

Most hardware relations in a device tree follow one pattern:
a **provider** node (a GPIO controller, clock controller, regulator, reset controller, interrupt controller)
is referenced by a **consumer** node through a **phandle + arguments**.
Linux subsystems parse these generic properties, so drivers don't need custom parsing code.

## 1. The provider/consumer pattern

```dts
gpio4: gpio@fe770000 {                 /* provider */
    gpio-controller;
    #gpio-cells = <2>;                 /* consumers pass 2 cells: pin, flags */
};

sensor@48 {                            /* consumer */
    reset-gpios = <&gpio4 RK_PD5 GPIO_ACTIVE_LOW>;   /* &provider + #gpio-cells arguments */
};
```

| Resource | Provider has | Consumer property | Name list (if several) | Driver API |
| --- | --- | --- | --- | --- |
| GPIO | `gpio-controller; #gpio-cells` | **`<name>-gpios`** (e.g. `reset-gpios`, `enable-gpios`); plain `gpios` for unnamed | (the prefix *is* the name) | `devm_gpiod_get(dev, "reset", ...)` |
| Regulator / power rail | a regulator node | **`<name>-supply`** (e.g. `vdd-supply`, `vmmc-supply`) | (the prefix *is* the name) | `devm_regulator_get(dev, "vdd")` |
| Clock | `#clock-cells` | **`clocks`** | **`clock-names`** | `devm_clk_get(dev, "bus")` |
| Reset line | `#reset-cells` | **`resets`** | **`reset-names`** | `devm_reset_control_get_exclusive(dev, "core")` |
| Interrupt | `interrupt-controller; #interrupt-cells` | `interrupts` (+ `interrupt-parent`), or `interrupts-extended` | `interrupt-names` | `platform_get_irq_byname()` |
| PWM | `#pwm-cells` | `pwms` | `pwm-names` | `devm_pwm_get()` |
| DMA | `#dma-cells` | `dmas` | `dma-names` | `dma_request_chan(dev, "tx")` |
| PHY | `#phy-cells` | `phys` | `phy-names` | `devm_phy_get()` |
| Pin configuration | the pin controller | `pinctrl-0`, `pinctrl-1`, ... | **`pinctrl-names`** | applied by the driver core (section 3) |

Notes:

+ The singular `-gpio` suffix is **deprecated**; write `-gpios`, even for one pin.
+ `clocks`/`resets`/`dmas` have **no** name prefix. The names go in the matching `*-names` list, in the same order:
  `clocks = <&cru CLK_UART2>, <&cru PCLK_UART2>; clock-names = "baudclk", "apb_pclk";`
+ Polarity is part of the GPIO specifier (`GPIO_ACTIVE_LOW`), so the driver can always use logical values: 1 = asserted.
+ Which names a device expects (`reset-gpios`, `vdd-supply`, ...) is defined by **its binding**, not chosen freely.

## 2. Core properties every device node uses

+ `compatible`: selects the driver (see [dts_driver_probe.md](dts_driver_probe.md)).
+ `reg`: register region(s) or bus address.
+ `interrupts` / `interrupts-extended`.
+ `status`: `"okay"` or `"disabled"`.

The details are in [dts_syntax.md](dts_syntax.md).

## 3. Pin control (pinctrl)

SoC pins are multiplexed: one ball can be a GPIO, UART TX, I2C SDA, ...
They also have electrical settings: pull-up/down, drive strength, slew rate, Schmitt trigger.
The **pin controller** node describes the possible configurations as child nodes.
**Consumers** select them by name.

### 3.1 Consumer side (the same for every SoC)

```dts
&uart2 {
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&uart2m0_xfer>;           /* state 0 = "default" */
    pinctrl-1 = <&uart2m0_xfer_sleep>;     /* state 1 = "sleep" */
    status = "okay";
};
```

+ `pinctrl-names` lists the state names. `pinctrl-N` gives the phandles for state N.
  One state can combine several pin groups: `pinctrl-0 = <&a>, <&b>;`.
+ The driver core applies **"default"** automatically **before** `probe()`.
  If an **"init"** state exists, it's applied before probe instead, and "default" after probe.
  Drivers switch to **"sleep"**/**"idle"** themselves (`pinctrl_pm_select_sleep_state()`).
+ A pin group that no node references is **never applied**.
  For pins that no driver owns (for example a GPIO used only from user space),
  add a **pinctrl hog**: put `pinctrl-names`/`pinctrl-0` in the pin controller node itself.

### 3.2 Provider side: generic binding

Many SoCs use the generic `pins`/`function`/`groups` + config properties (from `pinctrl/pinmux-node.yaml` and `pincfg-node.yaml`):

```dts
pinctrl: pinctrl@10000000 {
    compatible = "vendor,soc-pinctrl";
    reg = <0x10000000 0x1000>;

    uart0_pins: uart0-pins {
        pins = "gpio15", "gpio16";        /* pin NAMES (strings), as defined by that SoC's binding */
        function = "uart0";
        bias-pull-up;
        drive-strength = <12>;            /* mA */
    };
};
```

Common configuration properties: `bias-disable`, `bias-pull-up`, `bias-pull-down`, `drive-strength` (mA),
`input-enable`, `output-high`, `output-low`, `slew-rate`, `input-schmitt-enable`.

### 3.3 Provider side: Rockchip (RK3566) binding

Rockchip uses its own compact format: `rockchip,pins = <bank pin function &config>;`

```dts
#include <dt-bindings/pinctrl/rockchip.h>

&pinctrl {
    my-board {
        relay_en: relay-en {
            rockchip,pins = <4 RK_PD5 RK_FUNC_GPIO &pcfg_pull_none>;   /* GPIO4_D5 as GPIO, no pull */
        };
    };
};
```

`RK_PA0`…`RK_PD7` are pin numbers 0–31 within a bank, `RK_FUNC_GPIO` is mux 0, and `&pcfg_pull_none`/`&pcfg_pull_up`/... are config nodes from the SoC `.dtsi`.
See [dts_node_led_vs_gpio.md](dts_node_led_vs_gpio.md) for a complete LED / GPIO example.

## 4. Power: regulators instead of raw enable GPIOs

When a GPIO switches a **power rail**, describe it as a regulator (for example `regulator-fixed`) and connect it with `<name>-supply`.
The consumer driver then calls `regulator_enable()`.
The regulator framework handles reference counting (several consumers on one rail), delays, and sequencing.
A GPIO-switched fixed regulator is part of the regulator framework too, not an alternative to it.
See [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md).

## Related notes

+ [dts_intro.md](dts_intro.md), [dts_syntax.md](dts_syntax.md), [dts_driver_probe.md](dts_driver_probe.md)

## Reference

+ [Pinctrl subsystem (kernel docs)](https://docs.kernel.org/driver-api/pin-control.html)
+ [GPIO mappings: device tree (kernel docs)](https://docs.kernel.org/driver-api/gpio/board.html)
+ Bindings: `Documentation/devicetree/bindings/{gpio,regulator,clock,pinctrl}/` in the kernel tree
