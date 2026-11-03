# Device tree: a GPIO-switched power rail (`regulator-fixed`)

Suppose a GPIO switches the power of a peripheral, for example through a load switch or an LDO enable pin.
There are 2 ways to describe it. The recommended one is a **fixed regulator** that the peripheral uses as its `<name>-supply`.

## 1. Define a fixed regulator

```dts
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/pinctrl/rockchip.h>   /* RK_PB2 */

/ {
    vcc3v3_periph: regulator-vcc3v3-periph {
        compatible = "regulator-fixed";
        regulator-name = "vcc3v3_periph";          /* name in /sys/class/regulator/*/name and in logs */
        regulator-min-microvolt = <3300000>;       /* fixed: min == max */
        regulator-max-microvolt = <3300000>;
        gpio = <&gpio1 RK_PB2 GPIO_ACTIVE_HIGH>;   /* enable pin */
        enable-active-high;                        /* REQUIRED for active-high, see below */
        startup-delay-us = <1000>;                 /* wait after enabling before consumers use it */
        off-on-delay-us = <2000>;                  /* minimum off time before re-enabling */
        vin-supply = <&vcc_sys>;                   /* optional: the rail this switch is fed from */
        pinctrl-names = "default";
        pinctrl-0 = <&vcc3v3_periph_en>;           /* optional: mux + pull for the enable pin */
    };
};
```

+ **Polarity quirk**: for `regulator-fixed`, the active level comes from **`enable-active-high`**, not from the GPIO flag.
  Without that property the enable pin is treated as **active-low**, whatever `GPIO_ACTIVE_HIGH` says.
  The kernel warns about the mismatch. Keep the two consistent.
+ Use `gpio` (singular) for this binding, as documented in `fixed-regulator.yaml`.
+ The node name should start with `regulator-`. The label (`vcc3v3_periph:`) is used for references,
  and `regulator-name` is what shows up at runtime.

### Boot-time behavior

| Property | Effect |
| --- | --- |
| *(none)* | Off at boot. Turned on when a consumer calls `regulator_enable()` |
| `regulator-boot-on` | "The bootloader left it on." The kernel takes over in the on state. If **no consumer** enables it, it's **switched off** about 30 s after boot (`regulator_late_cleanup`) |
| `regulator-always-on` | Never switched off by the kernel. Use it for rails that must stay up even without a consumer |

## 2. Connect it to the consumer

```dts
&i2c1 {
    status = "okay";

    touchscreen@38 {
        compatible = "edt,edt-ft5406";
        reg = <0x38>;
        vcc-supply = <&vcc3v3_periph>;            /* the name ("vcc") is defined by the device's binding */
    };
};
```

The driver calls `devm_regulator_get(dev, "vcc")` and `regulator_enable()` in `probe()`, and `regulator_disable()` on suspend or remove.
The framework counts users, so 2 devices on the same rail work correctly. It also applies the delays and turns the GPIO on and off.

### Alternative: the device's own enable GPIO

If the **binding of the device** defines an enable/power-down pin, use that property instead:

```dts
&i2c1 {
    camera@3c {
        compatible = "ovti,ov5640";
        reg = <0x3c>;
        powerdown-gpios = <&gpio1 RK_PB2 GPIO_ACTIVE_HIGH>;
        reset-gpios = <&gpio1 RK_PB3 GPIO_ACTIVE_LOW>;
    };
};
```

Use this only when the binding lists such a property. A random `enable-gpios` that the driver doesn't read is silently ignored.
For a pin that cuts the **power rail** (rather than a chip's enable input), the regulator is the right model.

## 3. Checking

```shell
cat /sys/class/regulator/regulator.*/name                 # find vcc3v3_periph
cat /sys/class/regulator/regulator.N/state                # enabled / disabled (read-only)
cat /sys/class/regulator/regulator.N/num_users
cat /sys/kernel/debug/regulator/regulator_summary         # tree of rails, users, enable counts (debugfs)
dmesg | grep -i vcc3v3_periph
```

## 4. Switching it from user space or Android

The regulator sysfs files, including **`state`, are read-only**: user space **can't** turn a regulator on or off by writing them.
And it shouldn't: the consumer driver owns the rail.
If you really need user-space control, there are 3 options:

1. **No kernel consumer**: describe the pin as a plain GPIO (not a regulator) and switch it from a daemon or HAL with libgpiod
   (see [dts_node_leds.md](dts_node_leds.md#2-as-a-plain-gpio) and [../Android/AIDL_impl_gpio_cxx.md](../Android/AIDL_impl_gpio_cxx.md)).
2. **Kernel `userspace-consumer` regulator driver** (`CONFIG_REGULATOR_USERSPACE_CONSUMER`).
   A consumer node creates a device with a **writable** `state` attribute that enables or disables its supplies.
   Check the binding in your kernel version (`regulator-output` in recent kernels).
3. **The device's driver** exposes power control in its own way (runtime PM, rfkill for radios, ...).

On Android, apps never write these files.
A vendor HAL or daemon does, with its own SELinux domain and a `genfs_contexts` label for the node.
The pattern is in [../Android/hw_control_sysfs.md](../Android/hw_control_sysfs.md) and [../Android/neverallow_error.md](../Android/neverallow_error.md).
Rules such as `allow platform_app sysfs_regulator:file write` are the wrong design.

### Hardware safety

Check the schematic for the enable polarity, the rail voltage, and any power-sequencing requirements (which rails must come up first, and the delays)
**before** you enable a new rail. A wrong `enable-active-high` can power a chip at the wrong time or keep it on unexpectedly.

## Related notes

+ [dts_conventions.md](dts_conventions.md) (`-supply` convention), [dts_driver.md](dts_driver.md)
+ [dts_node_leds.md](dts_node_leds.md), [dts_syntax.md](dts_syntax.md)

## Reference

+ [fixed-regulator binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/regulator/fixed-regulator.yaml)
+ [Regulator consumer driver interface (kernel docs)](https://docs.kernel.org/power/regulator/consumer.html)
