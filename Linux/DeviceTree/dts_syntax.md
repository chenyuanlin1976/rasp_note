# DTS syntax and standard properties

The reference is the [Devicetree specification](https://www.devicetree.org/specifications/), chapters 2–3 and 6.
Kernel DTS files also go through the **C preprocessor**, so `#include`, `#define`, and the macros from `include/dt-bindings/*.h` work.

## 1. Nodes

```dts
[label:] node-name[@unit-address] {
    [properties]
    [child nodes]
};
```

+ The **root node** is `/ { ... };`. It has no name and no unit address.
+ **`node-name`** is a generic name for the device class: `serial`, `i2c`, `gpio`, `led`, `regulator`, `ethernet`, ...
  (the spec lists recommended names). It isn't the chip name.
+ **`@unit-address`** is the first address in the node's `reg` property: lowercase hex, no `0x`, no leading zeros (`serial@2020000`).
  A node with `reg` must have a unit address, and a node without `reg` must not have one.
+ **Labels** (`uart1:`) name a node so that other places can refer to it with **`&uart1`**.
  Labels exist only in the source; dtc turns references into **phandles**.
+ Inside a node, **properties come before child nodes**. Every node and property ends with `;`.

```dts
uart1: serial@2020000 {
    compatible = "fsl,imx6q-uart", "fsl,imx21-uart";
    reg = <0x02020000 0x4000>;
    status = "disabled";
};
```

## 2. Property values

| Form | Example | Meaning |
| --- | --- | --- |
| Empty (boolean) | `gpio-controller;` | True if present |
| Cells (u32 array) | `reg = <0x3000 0x20>;` | Space-separated 32-bit values in `< >`. C-style expressions in parentheses work: `<(1 << 4)>` |
| 64-bit / 8-bit cells | `/bits/ 64 <0x100000000>;`, `/bits/ 8 <0x12 0x34>;` | Different cell size |
| String | `status = "okay";` | NUL-terminated |
| String list | `compatible = "a,b", "c,d";` | Several strings |
| Bytestring | `mac-address = [02 03 04 05 06 07];` | Hex bytes in `[ ]` |
| Phandle reference | `interrupt-parent = <&gic>;` | `&label` inside `< >` becomes the target node's phandle |
| Phandle + arguments | `gpios = <&gpio4 RK_PD5 GPIO_ACTIVE_HIGH>;` | Provider phandle, then as many cells as the provider's `#...-cells` says |
| Mixed / several entries | `clocks = <&cru 12>, <&cru 13>;` | Comma-separated groups |
| Path reference | `stdout-path = &uart2;` (or `"serial2:1500000n8"`) | Full path of the node as a string |

## 3. Modifying and deleting

```dts
&uart1 {                            /* extend/override a labeled node from an included file */
    status = "okay";
};

&{/soc/serial@2020000} { ... };     /* same, by path */

/delete-node/ &uart3;               /* at top level: remove a labeled node */

&i2c1 {
    /delete-property/ clock-frequency;
    /delete-node/ eeprom@50;        /* remove a child by name */
};
```

When the same node is defined in several places, **the last definition of each property wins**.
That's why the board `.dts` (included last) can override the SoC `.dtsi`.

## 4. Standard properties

### 4.1 `compatible`

`compatible` is the link between a node and a driver.
It's a list of `"vendor,model"` strings, ordered from **most specific to most generic**:

```dts
compatible = "fsl,imx6q-uart", "fsl,imx21-uart";
```

Within one driver's `of_match_table`, the kernel picks the entry that matches the **earliest** (most specific) string.
Across drivers, the first registered driver that matches any string binds.
So a specific driver and a generic driver should not both claim the same hardware, or the result depends on load order.
Vendor prefixes are registered in `Documentation/devicetree/bindings/vendor-prefixes.yaml` (`fsl`, `st`, `ti`, `rockchip`, `ns`, ...).
See [dts_driver_probe.md](dts_driver_probe.md).

On the root node, `compatible` identifies the **board**, then the SoC (`"mycompany,my-board", "rockchip,rk3566"`).
`model` is a human-readable board name.

### 4.2 `status`

| Value | Meaning |
| --- | --- |
| `"okay"` (or no `status` at all) | Device is enabled; a driver may bind |
| `"disabled"` | Present but not enabled; the kernel creates no device, so no driver probes it |
| `"reserved"` | Operational but in use by other software (e.g. firmware); don't use it |
| `"fail"`, `"fail-<reason>"` | Error detected; not usable |

SoC `.dtsi` files define most peripherals as `"disabled"`, because which ones are wired up is a board decision.
The board `.dts` sets `"okay"` on the ones it uses.

### 4.3 `#address-cells`, `#size-cells`, `reg`

+ A parent's `#address-cells` and `#size-cells` say how many 32-bit cells its **children's** `reg` entries use for the address and for the size.
  They aren't inherited from grandparents. If they're missing, the spec defaults are 2 and 1, but **always write them**.
+ `reg = <address size [address size ...]>`: one or more regions in the **parent's** address space.

| Bus | Typical cells | `reg` example |
| --- | --- | --- |
| 64-bit SoC bus | `#address-cells = <2>; #size-cells = <2>;` | `reg = <0x0 0xfe650000 0x0 0x1000>;` |
| 32-bit SoC bus | `<1>; <1>;` | `reg = <0x3000 0x20 0xfe00 0x100>;` (2 regions) |
| I2C | `<1>; <0>;` | `reg = <0x48>;` (the 7-bit device address, no size) |
| SPI | `<1>; <0>;` | `reg = <0>;` (chip-select number) |
| `cpus` node | `<1>; <0>;` (or `<2>`) | `reg = <0x100>;` (CPU/MPIDR id) |

### 4.4 `ranges`, `dma-ranges`

+ `ranges = <child-addr parent-addr size ...>;` maps a bus's child address space into the parent's.
  An **empty** `ranges;` means the addresses are identical (1:1).
  Without `ranges`, the children aren't memory-mapped from the CPU's point of view (for example, devices on I2C).
+ `dma-ranges` is the same mapping for DMA **from** devices to memory. `dma-coherent;` marks a device as cache-coherent.

```dts
soc {
    compatible = "simple-bus";
    #address-cells = <1>;
    #size-cells = <1>;
    ranges = <0x0 0xe0000000 0x00100000>;   /* child 0x0 = CPU 0xe0000000, 1 MiB window */

    serial@4600 {
        compatible = "ns16550";
        reg = <0x4600 0x100>;               /* CPU address 0xe0004600 */
        interrupts = <10 8>;
        interrupt-parent = <&ipic>;
    };
};
```

### 4.5 Interrupts

| Property | Where | Meaning |
| --- | --- | --- |
| `interrupt-controller;` | controller | This node is an interrupt controller |
| `#interrupt-cells = <N>;` | controller | Number of cells in each interrupt specifier |
| `interrupt-parent = <&ctrl>;` | device or ancestor | Which controller (it **is** inherited from ancestors) |
| `interrupts = <...>;` | device | Specifier(s) for `interrupt-parent` |
| `interrupts-extended = <&ctrl1 ...>, <&ctrl2 ...>;` | device | Each interrupt names its own controller |
| `interrupt-names = "tx", "rx";` | device | Names for the entries, used by drivers |

On ARM GIC, there are 3 cells: `<GIC_SPI 66 IRQ_TYPE_LEVEL_HIGH>`, from `<dt-bindings/interrupt-controller/arm-gic.h>`.
A GPIO controller that is also an interrupt controller usually has 2 cells: `<RK_PA5 IRQ_TYPE_EDGE_FALLING>`.

### 4.6 `phandle`

Every node that is referenced gets a unique 32-bit `phandle`. **dtc assigns it automatically** from labels.
Writing `phandle = <1>;` by hand is legal, but it's only seen in old or generated sources:

```dts
pic: pic@10000000 {
    interrupt-controller;
    reg = <0x10000000 0x100>;
};

dev { interrupt-parent = <&pic>; };   /* dtc writes pic's phandle number here */
```

### 4.7 Special nodes

| Node | Purpose |
| --- | --- |
| `/chosen` | Boot parameters: `bootargs`, `stdout-path`, initrd location (usually filled in by the bootloader) |
| `/aliases` | Stable names → nodes: `serial0 = &uart2;`, `mmc0 = &sdhci;`, `ethernet0 = &gmac1;` (used for numbering ttyS/mmcblk) |
| `/memory@...` | RAM banks (`device_type = "memory"`; often patched by the bootloader) |
| `/reserved-memory` | Carve-outs: firmware, CMA, ramoops |
| `/cpus` | CPUs (`device_type = "cpu"`), plus `cpu-map`, idle states, OPP tables |

`device_type` is deprecated except for `cpu` and `memory` nodes (PCI host bindings still use `device_type = "pci"`).

## Related notes

+ [dts_intro.md](dts_intro.md), [dts_provider_consumer.md](dts_provider_consumer.md) (GPIO/regulator/clock/pinctrl conventions), [dts_coding_style.md](dts_coding_style.md)

## Reference

+ [Devicetree specification](https://www.devicetree.org/specifications/)
+ [DTS format (dtc docs)](https://git.kernel.org/pub/scm/utils/dtc/dtc.git/tree/Documentation/dts-format.txt)
