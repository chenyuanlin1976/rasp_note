# DTS coding style (Linux kernel)

This is a summary of the kernel's [Devicetree Sources (DTS) Coding Style](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html).
It applies to `.dts`/`.dtsi` files submitted to the kernel, and it's a good default elsewhere.
`make CHECK_DTBS=y` and `dtc` warnings catch many violations.

## 1. Names and characters

| Item | Allowed | Example |
| --- | --- | --- |
| Node and property names | `a-z`, `0-9`, `-` (dash); plus the `,` of a vendor prefix and the leading `#` of `#...-cells` | `led-status`, `reset-gpios`, `rockchip,pins` |
| Labels | `a-z`, `0-9`, `_` (underscore) | `gpi_dma2`, `vcc_3v3` |
| Unit address | lowercase hex, **no** `0x`, **no** leading zeros (unless the bus defines otherwise) | `dma-controller@a00000` |
| Hex values in properties | lowercase. The address part *may* be zero-padded | `reg = <0x0 0x00a00000 0x0 0x60000>;` |

Use **generic node names** that say what the node is (`serial`, `i2c`, `regulator`, `led`, `temperature-sensor`), not part numbers.

```dts
gpi_dma2: dma-controller@a00000 {
	compatible = "qcom,sm8550-gpi-dma", "qcom,sm6350-gpi-dma";
	reg = <0x0 0x00a00000 0x0 0x60000>;
};
```

## 2. Order of nodes

1. Nodes **with** unit addresses (children of a bus) are sorted by **unit address, ascending**.
   Some sub-architectures group nodes of the same type instead (all I2C controllers together).
2. Nodes **without** unit addresses are sorted **alphanumerically by node name**.
   A few types are sorted by a main property instead (for example, pin-configuration nodes by `pins`).
3. When the board DTS extends nodes with `&label { ... }`, those blocks are sorted alphanumerically by label,
   or kept in the DTSI order, depending on the sub-architecture.

These rules are easy to check in review, cause fewer merge conflicts, and make files easier to navigate.

## 3. Order of properties inside a node

1. `device_type` (only `cpu`/`memory` nodes)
2. `compatible`
3. `reg`
4. `ranges`
5. Standard/common properties (no vendor prefix), for example `#dma-cells`, `clocks`, `clock-names`, `interrupts`, `pinctrl-*`
6. Vendor-specific properties (`rockchip,...`)
7. `status` (if needed), preceded by a blank line when other properties come before it
8. Child nodes, each preceded by a blank line

`status = "okay"` is the default, so write it only to **override** a `"disabled"` from a DTSI.
Within each group, properties are usually in natural sort order by name, except for logical groups such as supplies.

## 4. Indentation and layout

+ Indent with **tabs**, one tab per nesting level.
+ For multi-line values (long `reg` or `interrupts` lists), align the continuation lines with the first value.
+ One property per line, and a blank line before each child node.

```dts
&i2c1 {
	clock-frequency = <400000>;
	pinctrl-0 = <&i2c1_xfer>;
	pinctrl-names = "default";

	status = "okay";

	temperature-sensor@48 {
		compatible = "ti,tmp102";
		reg = <0x48>;
		interrupts-extended = <&gpio0 RK_PA5 IRQ_TYPE_LEVEL_LOW>;
	};
};
```

## 5. Organizing DTSI and DTS files

+ **SoC DTSI**: everything that is *inside* the SoC, and nothing that isn't on the SoC.
+ **SoM / common DTSI** (if applicable): parts shared by several boards, such as a system-on-module.
+ **Board DTS**: everything that is *on the board*: regulators, LEDs, sensors, connectors, and the `status = "okay"` for used SoC blocks.

Board components belong in the board DTS, not in the SoC or SoM DTSI.
A partial exception is an external reference clock that the SoC always needs:
it can be a `fixed-clock` in the SoC DTSI, with its frequency set by each board.

## Related notes

+ [dts_syntax.md](dts_syntax.md), [dts_provider_consumer.md](dts_provider_consumer.md), [dts_intro.md](dts_intro.md)

## Reference

+ [Devicetree Sources (DTS) Coding Style (kernel docs)](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html)
