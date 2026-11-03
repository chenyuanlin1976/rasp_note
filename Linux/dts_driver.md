# Device tree and drivers: how a node becomes a probed device

The device tree describes hardware, and drivers contain the logic.
This note shows how the kernel connects them: it creates devices from the tree, matches them to drivers through `compatible`,
and the drivers read their resources in `probe()`.

## 1. `.dtsi` vs `.dts`

+ **`.dtsi`** (SoC include): the blocks inside the chip, such as CPUs, interrupt controller, timers, UART/I2C/SPI controllers, and GPIO banks.
  Most peripherals are `status = "disabled"` here.
+ **`.dts`** (board): includes the `.dtsi`, sets `status = "okay"` on the blocks the board uses, and adds the board's own devices (PMIC, sensors, LEDs, regulators).

More in [dts_intro.md](dts_intro.md).

## 2. From DTB to device objects

1. **Build**: `cpp` + `dtc` turn `.dts` + `.dtsi` into a `.dtb`.
2. **Boot**: the bootloader loads the DTB and passes its address to the kernel. The kernel *unflattens* it into `struct device_node`s.
3. **Device creation**: device structures are created **by whoever owns the parent bus**:
   + Children of the root node and of `simple-bus` nodes become **platform devices** (`of_platform_populate()`).
   + Children of an **I2C/SPI controller** node are created by that controller's driver, when it probes, as `i2c_client`/`spi_device`.
     That's why a sensor under `&i2c1` appears only after the I2C controller driver is working.
   + Nodes with `status = "disabled"` are **skipped**: no device is created.
4. **Matching**: the bus compares the node's `compatible` list with each driver's `of_match_table`, and calls `probe()` on a match.
5. **Dependencies**: if `probe()` needs a resource that isn't ready yet (a clock, regulator, or GPIO), it returns **`-EPROBE_DEFER`**, and the kernel retries later.
   `fw_devlink` (`fw_devlink=on`, the default) orders probing from the phandle references, so most of this happens automatically.

## 3. Matching through `compatible`

```dts
/* SoC .dtsi */
i2c1: i2c@fe5a0000 {
    compatible = "vendor,soc-i2c";
    reg = <0x0 0xfe5a0000 0x0 0x1000>;
    interrupts = <GIC_SPI 47 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&cru CLK_I2C1>, <&cru PCLK_I2C1>;
    clock-names = "i2c", "pclk";
    #address-cells = <1>;
    #size-cells = <0>;
    status = "disabled";               /* enabled by the board .dts */
};
```

```c
/* driver .c */
static const struct of_device_id my_i2c_of_match[] = {
	{ .compatible = "vendor,soc-i2c", .data = &soc_i2c_cfg },  /* .data: per-variant config */
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, my_i2c_of_match);   /* lets udev/modprobe autoload the module ("of:N...Cvendor,soc-i2c") */

static struct platform_driver my_i2c_driver = {
	.probe = my_i2c_probe,
	.driver = {
		.name = "my-i2c",
		.of_match_table = my_i2c_of_match,
	},
};
module_platform_driver(my_i2c_driver);
```

+ A node lists a specific string plus generic fallbacks, so that an older kernel without the specific driver still finds one.
  Within a driver's table, the best (earliest) string is used. Across drivers, the first registered driver that matches binds.
+ `of_device_get_match_data(&pdev->dev)` (or `device_get_match_data()`) returns the `.data` of the entry that matched,
  so one driver can support several chip variants.
+ Without `MODULE_DEVICE_TABLE`, a modular driver doesn't load automatically, even when the DT node is correct.

## 4. Reading resources in `probe()`

Use the **managed** (`devm_*`) and **firmware-agnostic** helpers. They are released automatically on unbind,
and the `device_property_*` ones also work with ACPI.

```c
static int my_i2c_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	const struct soc_i2c_cfg *cfg = device_get_match_data(dev);
	void __iomem *base;
	struct clk *clk;
	struct gpio_desc *reset;
	u32 freq = 100000;
	int irq;

	base = devm_platform_ioremap_resource(pdev, 0);          /* reg[0] */
	if (IS_ERR(base))
		return PTR_ERR(base);

	irq = platform_get_irq(pdev, 0);                          /* interrupts[0] */
	if (irq < 0)
		return irq;

	clk = devm_clk_get_enabled(dev, "i2c");                   /* clocks + clock-names */
	if (IS_ERR(clk))
		return dev_err_probe(dev, PTR_ERR(clk), "no clock\n");   /* also handles -EPROBE_DEFER quietly */

	reset = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);   /* reset-gpios, polarity from DT */
	if (IS_ERR(reset))
		return PTR_ERR(reset);

	device_property_read_u32(dev, "clock-frequency", &freq);  /* optional property, keeps the default if absent */

	/* ... set up the hardware using cfg, base, irq ... */
	return 0;
}
```

| DT property | API |
| --- | --- |
| `reg` | `devm_platform_ioremap_resource(pdev, i)` (or `platform_get_resource()` + `devm_ioremap_resource()`) |
| `interrupts` | `platform_get_irq(pdev, i)` / `platform_get_irq_byname()` |
| `clocks` | `devm_clk_get[_enabled](dev, "name")` |
| `<name>-gpios` | `devm_gpiod_get(dev, "name", flags)`. The legacy `of_get_named_gpio()` + integer GPIO API is deprecated |
| `<name>-supply` | `devm_regulator_get(dev, "name")` + `regulator_enable()` |
| `resets` | `devm_reset_control_get_exclusive(dev, "name")` |
| scalar/string properties | `device_property_read_u32/_bool/_string()` (or the DT-only `of_property_read_*()`) |
| child nodes | `device_for_each_child_node(dev, child)` |

## 5. Example: a GPIO consumer, with polarity handled by the device tree

```dts
sensor@68 {
    compatible = "vendor,my-sensor";
    reg = <0x68>;
    enable-gpios = <&gpio1 RK_PB4 GPIO_ACTIVE_HIGH>;   /* looked up as "enable" */
    reset-gpios = <&gpio2 RK_PA5 GPIO_ACTIVE_LOW>;     /* looked up as "reset"; asserted = pin LOW */
};
```

```c
static int my_sensor_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct gpio_desc *enable, *reset;

	/* The "-gpios" suffix is added by the lookup. _optional returns NULL if the property is absent */
	enable = devm_gpiod_get_optional(dev, "enable", GPIOD_OUT_LOW);
	if (IS_ERR(enable))
		return dev_err_probe(dev, PTR_ERR(enable), "enable gpio\n");

	reset = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);   /* start with reset ASSERTED (logical 1) */
	if (IS_ERR(reset))
		return dev_err_probe(dev, PTR_ERR(reset), "reset gpio\n");

	gpiod_set_value_cansleep(enable, 1);   /* power the chip (a NULL descriptor is a no-op) */
	usleep_range(1000, 2000);              /* datasheet power-up time */
	gpiod_set_value_cansleep(reset, 0);    /* release reset: the pin goes HIGH because it is ACTIVE_LOW */
	return 0;
}
```

+ **Logical values**: `1` means "asserted/active" and `0` means "inactive".
  The `GPIO_ACTIVE_LOW` flag in the device tree makes gpiolib invert the value,
  so a board revision that flips the polarity changes only the `.dts`, never the driver.
+ Use the `_cansleep` variants unless you're in atomic context.
  GPIOs behind I2C/SPI expanders can sleep, and `gpiod_set_value()` warns on them.
+ The descriptor is released automatically (`devm_`) when the driver unbinds.
  Integer GPIO numbers (`gpio_request()`, `of_get_named_gpio()`) are the deprecated legacy API.

## 6. Debugging "my driver doesn't probe"

```shell
ls /sys/firmware/devicetree/base/...                  # is the node in the LIVE tree (right DTB loaded)?
cat /sys/firmware/devicetree/base/<path>/status       # "okay"?
ls /sys/bus/platform/devices/ | grep fe5a0000         # was a device created?
ls -l /sys/bus/platform/devices/fe5a0000.i2c/driver   # is a driver bound?
cat /sys/kernel/debug/devices_deferred                # stuck in -EPROBE_DEFER? (debugfs)
dmesg | grep -i -E "fe5a0000|probe|defer"
```

## Summary

1. Describe the SoC block in the `.dtsi` and enable it in the board `.dts`.
2. `dtc` builds the `.dtb`, and the bootloader passes it to the kernel.
3. The parent bus creates a device for each enabled node.
4. `compatible` matches it to a driver's `of_match_table` (and `MODULE_DEVICE_TABLE` autoloads the module).
5. `probe()` gets registers, IRQs, clocks, GPIOs, and supplies with the `devm_*` helpers, and returns `-EPROBE_DEFER` if a dependency isn't ready.

## Related notes

+ [dts_intro.md](dts_intro.md), [dts_syntax.md](dts_syntax.md), [dts_conventions.md](dts_conventions.md)
+ [HAL_DeviceTree.md](HAL_DeviceTree.md)

## Reference

+ [Linux and the Devicetree (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
+ [Device driver infrastructure: deferred probe (kernel docs)](https://docs.kernel.org/driver-api/driver-model/driver.html)
+ [GPIO descriptor consumer interface (kernel docs)](https://docs.kernel.org/driver-api/gpio/consumer.html)
