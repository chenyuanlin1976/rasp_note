# Editing a board device tree: workflow and checklist (RK3566)

This note is the practical workflow for enabling and configuring a peripheral in a board `.dts`, with an RK3566 example.
The concepts behind each step are in the other device tree notes:
layering in [dts_intro.md](dts_intro.md), syntax in [dts_syntax.md](dts_syntax.md),
`clocks`/`-gpios`/`-supply`/pinctrl in [dts_provider_consumer.md](dts_provider_consumer.md),
and how a node becomes a probed driver in [dts_driver_probe.md](dts_driver_probe.md).

## 1. Where changes go

| File | Contains | Edit it? |
| --- | --- | --- |
| SoC `.dtsi` (`rk3566.dtsi` and what it includes) | Every block inside the SoC, mostly `status = "disabled"` | **No**. Override from the board file instead |
| SoM / common `.dtsi` | Parts shared by several boards (PMIC, eMMC) | Only for changes that apply to every board using it |
| Board `.dts` | What is wired on this board: enabled blocks, pin mux choices, regulators, sensors, LEDs | **Yes** |

The board file refers to SoC nodes by **label** (`&i2c3`), and the last definition of a property wins.
So the board can enable, reconfigure, or delete properties without touching the SoC file.
On RK3566, the files are in `arch/arm64/boot/dts/rockchip/`. Which `.dtsi` defines the labels depends on the kernel (mainline vs Rockchip BSP), see [dts_intro.md](dts_intro.md#3-file-layering).

## 2. Workflow: enabling a peripheral

The example adds a PCF8563 RTC on **I2C3**, wired to the **M1** pin set, on an RK3566 board.

### 2.1 Find the controller in the SoC files

```shell
cd arch/arm64/boot/dts/rockchip
grep -n "i2c3: i2c@" rk35*.dtsi                 # node, address, default status
grep -n "i2c3m[01]_xfer" rk3568-pinctrl.dtsi    # available pin groups
```

You'll find a node like `i2c3: i2c@fe5c0000 { ... status = "disabled"; }` with a default `pinctrl-0` (usually the M0 group).
Never copy the node into the board file. Reference it with `&i2c3`.

### 2.2 Read the bindings

Each `compatible` has a YAML binding under `Documentation/devicetree/bindings/` that lists the required and optional properties.
Here: the Rockchip I2C binding (`clock-frequency`, ...) and the RTC binding (`nxp,pcf8563`: `compatible`, `reg`, optional interrupt).

### 2.3 Check the schematic

+ **Pin set**: many RK3566 blocks can come out on two pin sets (`m0`/`m1`). The schematic tells you which one the board uses.
+ **IO voltage domain**: each pin bank's supply (1.8 V or 3.3 V) must be declared in the `io-domains` node, or the pins won't work correctly.
+ **Device address and lines**: the I2C address (`0x51`), interrupt pin, reset/enable pins, supply rails.

### 2.4 Write the board override

```dts
/* board .dts */
&i2c3 {
    status = "okay";
    clock-frequency = <400000>;             /* 400 kHz fast mode */
    pinctrl-names = "default";
    pinctrl-0 = <&i2c3m1_xfer>;             /* the board uses the M1 pins, not the SoC default */

    rtc@51 {
        compatible = "nxp,pcf8563";
        reg = <0x51>;                       /* 7-bit I2C address; matches the unit address */
    };
};

&pmu_io_domains {
    status = "okay";
    vccio4-supply = <&vcc_1v8>;             /* example: this bank is powered at 1.8 V on this board */
    /* ... one <bank>-supply per IO bank, from the schematic ... */
};
```

+ The parent `i2c3` node in the SoC `.dtsi` already has `#address-cells = <1>; #size-cells = <0>;`,
  so a child's `reg` is one cell (the I2C address) with no size.
+ The pinctrl `default` state is applied by the driver core before `probe()`.
  Clocks are different: the driver enables them itself (for example with `devm_clk_get_enabled()`).
+ The supply labels (`vcc_1v8`, ...) are board regulators. Use the names from your board's `.dts`.

### 2.5 Aliases (optional)

Aliases fix the device numbering, so that `i2c3` becomes `/dev/i2c-3` and `uart2` becomes `ttyS2`:

```dts
/ {
    aliases {
        i2c3 = &i2c3;
        serial2 = &uart2;
    };
};
```

The SoC `.dtsi` usually defines these already. Add or change them only when the board needs a different numbering.

## 3. Build and validate

Kernel `.dts` files use `#include` and macros, so build them through the kernel build (it runs `cpp` before `dtc`).
Calling `dtc` directly on the source fails on the `#include` lines.

```shell
make ARCH=arm64 rockchip/my-board.dtb                  # one board
make ARCH=arm64 CHECK_DTBS=y rockchip/my-board.dtb     # also check against the YAML bindings
```

+ Treat `dtc` warnings as errors: unit address vs `reg` mismatch, missing `#address-cells`, duplicate nodes.
+ Enable the driver in the kernel config too (here `CONFIG_RTC_DRV_PCF8563`). A correct node without a driver does nothing.
+ On Android, the Rockchip SDK packs the DTB into an image (the `resource` image or the boot image, depending on the SDK). Rebuild and flash that image.

## 4. Verify on the board

```shell
ls /proc/device-tree/ | grep fe5c0000                    # node present in the LIVE tree?
cat /proc/device-tree/i2c@fe5c0000/status; echo          # "okay"?
ls /proc/device-tree/i2c@fe5c0000/                       # rtc@51 child present?
ls -l /sys/bus/i2c/devices/3-0051/driver                 # device created and driver bound?
dmesg | grep -iE "i2c|rtc|fe5c0000"
cat /sys/kernel/debug/pinctrl/pinctrl-handles            # which pin groups were applied (debugfs)
```

On Android, run these through `adb shell` (`adb root` for debugfs and dmesg).
The platform device side (`/sys/bus/platform/devices/fe5c0000.i2c/driver`) is explained in [sysfs_platform_devices.md](sysfs_platform_devices.md).
If nothing probes, follow [dts_driver_probe.md](dts_driver_probe.md#5-debugging-my-driver-doesnt-probe).

## 5. Common mistakes

| Symptom | Likely cause |
| --- | --- |
| Node in the live tree but no device | `status` still `"disabled"`, or a parent bus is disabled |
| Device exists but no driver binds | `compatible` typo, or the driver isn't enabled in the kernel config |
| Changes don't show up in `/proc/device-tree` | The bootloader loads a different DTB, or an overlay (`dtbo`) changes the node |
| I2C/UART times out or reads garbage | Wrong pin set (`m0` vs `m1`), or wrong IO-domain voltage |
| `pin ... already requested` in dmesg | Two nodes use the same pins (e.g. a GPIO and a UART) |
| `probe` keeps deferring | A referenced clock, regulator, or GPIO provider isn't ready or isn't enabled |
| Edits lost after a BSP update | You edited the SoC `.dtsi`; move the change to the board `.dts` |

## Related notes

+ [dts_intro.md](dts_intro.md): file layering, build flow, overlays
+ [dts_syntax.md](dts_syntax.md): nodes, properties, `reg`/cells, special nodes (`/chosen`, `/aliases`, `/memory`, `/cpus`)
+ [dts_provider_consumer.md](dts_provider_consumer.md): providers/consumers and pinctrl
+ [dts_coding_style.md](dts_coding_style.md): naming, ordering, and what goes in SoC vs board files
+ [dts_driver_probe.md](dts_driver_probe.md): matching, `probe()`, and probe debugging
+ [dts_pinctrl_gpio_direction.md](dts_pinctrl_gpio_direction.md): pinctrl for a GPIO, RK3566 example
+ [sysfs_platform_devices.md](sysfs_platform_devices.md): the probed devices in `/sys/devices/platform`

## Reference

+ [Linux and the Devicetree (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
+ [Devicetree Sources (DTS) Coding Style (kernel docs)](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html)
+ [Writing devicetree bindings in json-schema (kernel docs)](https://docs.kernel.org/devicetree/bindings/writing-schema.html)
+ [Devicetree specification](https://www.devicetree.org/specifications/)
