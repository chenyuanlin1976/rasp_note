# Device tree introduction

A **devicetree** (DT) is a data structure that **describes the hardware** of a board to the operating system:
which devices exist, where their registers are, which interrupts, clocks, GPIOs, and power rails they use, and how they're connected.
It is **data, not code**. The kernel's drivers do the work; the device tree only tells them what is there.

+ It's a **tree** of **nodes**. Every node except the root has exactly one parent.
+ Each node has **properties** (name/value pairs) and may have child nodes.

Specification: [devicetree.org](https://www.devicetree.org/specifications/).

## 1. History

+ The format comes from **Open Firmware** (IEEE 1275), used on PowerPC and SPARC.
  Linux/PowerPC adopted the flattened device tree and `dtc` in the mid-2000s (2.6 era), and Power.org's ePAPR standardized it.
+ **ARM** Linux switched from per-board C files (`board-*.c`, "board files") to device tree around **2011–2012 (Linux 3.x)**.
  That is the "DT was introduced in 3.x" you often read. It applies to ARM only.
+ Today, DT is used on ARM/ARM64, RISC-V, PowerPC, MIPS, and others, and by bootloaders (U-Boot) and other kernels (Zephyr, FreeBSD).
  x86 PCs and ARM servers mostly use **ACPI** instead.

## 2. Terms

| Term | Meaning |
| --- | --- |
| **DTS** | Device Tree Source: the human-readable **text** (ASCII) source of a board |
| **DTSI** | Device Tree Source **Include**: shared parts that DTS files `#include`. Usually the SoC (`rk3566.dtsi`), sometimes a module (SoM) or board family |
| **DTC** | Device Tree Compiler (`dtc`): turns DTS into DTB (and back) |
| **DTB** | Device Tree **Blob**: the compiled binary (flattened device tree, FDT) that the bootloader passes to the kernel |
| **DTBO** | Device Tree **Overlay** blob: a fragment applied on top of a DTB (by the bootloader, or by Android's `dtbo` partition) to add or change nodes |
| **Binding** | The documented contract for one kind of node: required properties and allowed values. In the kernel, it's a YAML schema under `Documentation/devicetree/bindings/` |

## 3. File layering

Like C headers, files include each other, so the description of a chip is written once and reused by every board:

```text
my-board.dts                       board: enables the peripherals it uses, adds LEDs, sensors, regulators
  #include "my-som.dtsi"             optional: system-on-module parts (PMIC, eMMC)
    #include "rk3566.dtsi"           SoC: OPP tables and other RK3566 specifics
      #include "rk3566-base.dtsi"    RK3566 differences from RK3568
        #include "rk356x-base.dtsi"  blocks shared by RK3566/RK3568: CPUs, GIC, GPIO banks, UART, I2C, ...
                                     (mostly status = "disabled")
```

That is the **mainline** chain (Linux 6.x; older mainline kernels had a single `rk356x.dtsi`).
The **Rockchip BSP** kernel (4.19 / 5.10, used by most RK3566 Android SDKs) is simpler:
`rk3566.dtsi` includes `rk3568.dtsi` directly. Check the `#include` lines of the tree you actually build.

The board file includes the SoC file, then **extends or overrides** nodes by label:

```dts
// my-board.dts
/dts-v1/;
#include "rk3566.dtsi"

/ {
    model = "My RK3566 Board";
    compatible = "mycompany,my-board", "rockchip,rk3566";
};

&uart2 {
    status = "okay";        /* the SoC .dtsi defines uart2 as disabled; this board uses it */
};
```

In the kernel tree, the SoC and board files for Rockchip ARM64 are in `arch/arm64/boot/dts/rockchip/`.

## 4. From source to running kernel

```text
*.dts + *.dtsi --cpp (C preprocessor: #include, #define, dt-bindings/*.h)--> --dtc--> board.dtb
                                                                                          |
bootloader (U-Boot, ...) loads the DTB (and applies overlays), may patch it (memory size, MAC, bootargs)
                                                                                          v
kernel receives a pointer to it (ARM64: register x0) -> unflattens it -> creates devices -> drivers probe
```

```shell
make dtbs                                   # in a kernel tree: build all DTBs for ARCH
make rockchip/my-board.dtb                  # one board (ARCH=arm64)
dtc -I dtb -O dts -o out.dts board.dtb      # decompile a DTB
dtc -I fs  -O dts /proc/device-tree         # dump the LIVE tree of the running system
```

On a running system, the tree is visible at `/proc/device-tree/` (a link to `/sys/firmware/devicetree/base/`).

## 5. Validating against bindings

Modern kernels check DTS files against the YAML binding schemas (tool: `dt-schema`, `pip install dtschema`):

```shell
make dt_binding_check                                  # check the schemas themselves
make CHECK_DTBS=y rockchip/my-board.dtb                # check one board's DTB against all schemas
make dtbs_check                                        # check all DTBs (slow)
```

Most "my node is ignored" problems come from a property name, compatible string, or value format that doesn't match the binding.

## 6. Overlays

An overlay (`.dtso`/`.dtbo`) adds or changes nodes **without rebuilding** the base DTB.
Typical uses are HATs and capes on Raspberry Pi/BeagleBone, display or camera variants, and Android's `dtbo` partition.

```dts
/dts-v1/;
/plugin/;

&i2c1 {
    status = "okay";
    #address-cells = <1>;
    #size-cells = <0>;

    temp-sensor@48 {
        compatible = "ti,tmp102";
        reg = <0x48>;
    };
};
```

Build with `dtc -@ -I dts -O dtb -o sensor.dtbo sensor.dtso`.
The base DTB must be built with `-@` (symbols) so that `&i2c1` can be resolved.

## Related notes

+ [dts_syntax.md](dts_syntax.md): syntax and standard properties
+ [dts_provider_consumer.md](dts_provider_consumer.md): provider/consumer conventions (`-gpios`, `-supply`, `clocks`, pinctrl)
+ [dts_coding_style.md](dts_coding_style.md): kernel DTS coding style
+ [dts_driver_probe.md](dts_driver_probe.md): how drivers match and read nodes
+ [dts_node_led_vs_gpio.md](dts_node_led_vs_gpio.md), [dts_node_regulator_fixed.md](dts_node_regulator_fixed.md): concrete nodes
+ [HAL_DeviceTree.md](HAL_DeviceTree.md): DT → driver → user-space HAL

## Reference

+ [Devicetree specification](https://www.devicetree.org/specifications/)
+ [Linux and the Devicetree (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
+ [Writing devicetree bindings in json-schema (kernel docs)](https://docs.kernel.org/devicetree/bindings/writing-schema.html)
+ [Devicetree overlays (kernel docs)](https://docs.kernel.org/devicetree/overlay-notes.html)
