# dts coding

[dts-coding-style](https://docs.kernel.org/devicetree/bindings/dts-coding-style.html)

## Naming and Valid Characters

The Devicetree Specification allows a broad range of characters in node and property names,  
but this coding style narrows the range down to achieve better code readability.

+ **Node and property names** can use only the following characters:
  + Lowercase characters: [a-z]
  + Digits: [0-9]
  + Dash: -
+ **Labels** can use only the following characters:
  + Lowercase characters: [a-z]
  + Digits: [0-9]
  + Underscore: _
+ Unless a bus defines differently, **unit addresses** shall use lowercase hexadecimal digits, without leading zeros (padding).  
+ **Hex values in properties**, e.g. "reg", shall use lowercase hex. The address part can be padded with leading zeros.  

```C
gpi_dma2: dma-controller@a00000 {
  compatible = "qcom,sm8550-gpi-dma", "qcom,sm6350-gpi-dma";
  reg = <0x0 0x00a00000 0x0 0x60000>;
}
```

## Order of Nodes

1. Nodes on any bus, thus using unit addresses for children, shall be ordered by unit address **in ascending order**.  
   Alternatively for some subarchitectures, nodes of the same type can be grouped together,  
   e.g. all I2C controllers one after another even if this breaks unit address ordering.  
2. Nodes without unit addresses shall be ordered alpha-numerically by the node name.  
   For a few node types, they can be ordered by the main property,  
   e.g. pin configuration states ordered by value of "pins" property.
3. When extending nodes in the board DTS via &label, the entries shall be ordered either alpha-numerically or by keeping the order from DTSI,  
   where the choice depends on the subarchitecture.

The above-described ordering rules are easy to enforce during review, reduce chances of conflicts for simultaneous additions of new nodes to a file  
and help in navigating through the DTS source.

## Order of Properties in Device Node

The following order of properties in device nodes is **preferred**:

1. "compatible"
2. "reg"
3. "ranges"
4. Standard/common properties (defined by common bindings, e.g. without vendor-prefixes)
5. Vendor-specific properties
6. "status" (if applicable), preceded by a blank line if there is content before the property
7. Child nodes, where each node is preceded with a blank line

The "status" property is by default "okay", thus it can be omitted.
The above-described ordering follows this approach:

1. Most important properties start the node: compatible then bus addressing to match unit address.
2. Each node will have common properties in similar place.
3. **Status is the last information** to annotate that device node is or is not finished (board resources are needed).

The individual properties inside each group shall use natural sort order by the property name.

## Organizing DTSI and DTS

The DTSI and DTS files shall be organized in a way representing the common, reusable parts of hardware.  
Typically, this means organizing DTSI and DTS files into several files:  

+ DTSI with contents of the entire SoC, without nodes for hardware not present on the SoC.
+ If applicable: DTSI with common or re-usable parts of the hardware, e.g. entire System-on-Module.
+ DTS representing the board.

Hardware components that are present on the board shall be placed in the board DTS, not in the SoC or SoM DTSI.  
A partial exception is a common external reference SoC input clock, which could be coded as a fixed-clock in the SoC DTSI with its frequency provided by each board DTS.  
