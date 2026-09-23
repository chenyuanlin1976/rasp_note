# DTS Syntax format

+ each **node** in the devicetree is named according to the following convention: `node-name@unit-address`
+ The **root node** does not have a node-name or unit-address. It is identified by a forward slash `/`.
+ **Labels** are created by appending a colon `:` to the label name.
+ **References** are created by prefixing the label name with an ampersand `&`.
+ A bytestring is enclosed in square brackets `[]` with each byte represented by two hexadecimal digits. Spaces between each byte are optional. `mac-address = [02 03 04 05 06 07];`  

## Node and property definitions

+ **nodes** are defined with a `node-name` and `unit-address`  
  with braces marking the start and end of the node definition. They may be preceded by a label.
  Nodes may contain property definitions and/or child node definitions. If both are present, properties shall come before child nodes.
+ Previously defined nodes may be deleted.  
  `/delete-node/ node-name;`  
  `/delete-node/ &label;`  
+ **Property definitions** are **name value pairs** in the form.
  Property values may be defined as an array of 32-bit integer cells, as null-terminated strings, as bytestrings or a combination of these.  
  `[label:] property-name = value;`  
  `size = <0x4000000>;`  
+ Previously defined properties may be deleted.  
  `/delete-property/ property-name;`
+ Arrays of cells are represented by angle brackets surrounding a space separated list of C-style integers.  
  `interrupts = <17 0xc>;`

## node structure

the `[]` means it could be an option.

```ini
[label:] node-name[@unit-address] {
    [properties definitions]
    [child-nodes]
};
```

### example of a node

```ini
uart1: serial@02020000 {
    compatible = "fsl,imx6q-uart";
    reg = <0x02020000 0x4000>;
    status = "disabled";

    uart1_child {
        // the content of the sub-node
    };
};
```

## an example of DTS (a)

```ini
cpus {
  #address-cells = <1>;
  #size-cells = <0>;
  cpu@0 {
    device_type = "cpu";
    reg = <0>;
    d-cache-block-size = <32>;      // L1- 32 bytes
    i-cache-block-size = <32>;      // L1- 32 bytes
    d-cache-size = <0x8000>;        // L1, 32K
    i-cache-size = <0x8000>;        // L1, 32K
    timebase-frequency = <82500000>;// 82.5 MHz
    clock-frequency = <825000000>;  // 825 MHz
  };
};
```

## an example of DTS (b)

```ini
soc {
  compatible = "simple-bus";
  #address-cells = <1>;             // 1 u32 cell used to encode the address field
  #size-cells = <1>;                // 1 u32 cell used to encode the size    field
  ranges = <0x0 0xe0000000 0x00100000>;
  serial@4600 {                     // serial device
    device_type = "serial";
    compatible = "ns16550";
    reg = <0x4600 0x100>;           // a 256-byte block at offset 0x4600
    clock-frequency = <0>;
    interrupts = <0xA 0x8>;
    interrupt-parent = <&ipic>;
  };
};
```

## Standard Properties

### compatible property

the compatible property is one of the most critical elements.  
It acts as the bridge between hardware descriptions and device drivers in operating systems like Linux.

#### What Does compatible Do?

The compatible property tells the operating system's kernel  
which device driver should handle a specific hardware component.  
When the kernel boots up, it parses the compiled Device Tree (.dtb).  
For every node that contains a compatible property, the kernel searches its registered drivers to find a matching string.  
Once a match is found, the kernel invokes that driver's probe() function to initialize the hardware.

#### Syntax and Structure

The property consists of one or more text strings enclosed in quotes,  
typically following the industry standard format:   `compatible = "manufacturer,model"`

+ **Manufacturer** (Vendor Prefix): Identifies the company that made the chip or board  
  (e.g., fsl for Freescale/NXP, st for STMicroelectronics, ns for National Semiconductor, snps for Synopsys).
+ **Model**: Specifies the exact part number or IP block name (e.g., imx28-auart, stm32h7-uart, ns16550a).

```ini
uart0: serial@11000000 {
    compatible = "ns16550a";
    reg = <0x11000000 0x1000>;
    interrupts = <0 48 4>;
    status = "disabled";
};
```

##### Multiple Strings (Fallbacks)

Often, you will see a compatible property with a list of multiple strings, ordered from most specific to least specific:  
The kernel checks the list sequentially.  
It will first look for a driver matching the exact specific model (board-model-v2).  
If no exact driver is found, it falls back to a generic or older driver (board-model-v1) that is backwards-compatible with the hardware interface.

+ `compatible = "vendor,board-model-v2", "vendor,board-model-v1";`
+ `compatible = "fsl,mpc8641", "ns16550";`

#### Role Specific to .dtsi Files

Because .dtsi files are template files meant to describe generic System-on-Chips (SoCs) or shared hardware blocks  
(included by various board-level .dts files):

+ Reusability: A .dtsi file for an SoC will define standard peripherals  
  (like UARTs, I2C controllers, and timers) with their generic compatible strings.
+ Disabled by Default: In .dtsi files, peripherals often have their `status = "disabled";` property set alongside compatible.  
  The specific board .dts file will then include the .dtsi, override `status = "okay";` for the peripherals actually wired up on that board,  
  and inherit the compatible string automatically.   

### model property

`model = "fsl,MPC8349EMITX";`

### phandle property

+ Property name: phandle
+ Value type: `<u32>`
+ Description: The phandle property specifies a numerical identifier for a node that is unique within the devicetree.  
  The phandle property value is **used by other nodes** that need to refer to the node associated with the property.

```ini
  pic@10000000 {
    phandle = <1>;          // A phandle value of 1 is defined.
    interrupt-controller;
    reg = <0x10000000 0x100>;
  };
```

Another device node could reference the pic node with a phandle value of 1:

```ini
  another-device-node {
    interrupt-parent = <1>;
  };
```

### status property

In a Device Tree, the **status** property is used to control  
**whether a specific hardware device is enabled and initialized by the operating system kernel (such as Linux) during boot.**  
It acts like an on/off switch for driver loading,  
which is incredibly useful for separating shared hardware definitions from board-specific configurations.

#### Standard Values for status

+ `"okay"`: The device is operational and ready to be used.  
  The kernel will look for a matching driver, allocate resources, and initialize the hardware.  
+ `"disabled"`: The device is present in the hardware description but is not currently operational or should not be activated.  
  The kernel will completely ignore this node and will not load a driver for it.  
+ `"fail"` / `"fail-..."`: (Rarely used) Indicates that an operational error was detected, making the device unusable.
+ `"reserved"`: (Rarely used) Indicates the device is operational but should not be used by the OS  
  (often used for memory regions or co-processors).  

#### Why is this useful? (The DTSI vs. DTS split)

A System-on-Chip (SoC) usually has dozens of built-in peripherals (like 6 UART ports, 4 I2C buses, and 3 SPI controllers).  
However, a specific circuit board using that SoC might only physically connect wires to 2 of those UART ports.

1. In the .dtsi file (The SoC blueprint):  
   All hardware blocks are defined, but they are often set to status = "disabled";  
   by default so they don't waste system resources or crash the system trying to talk to pins that aren't hooked up.
2. In the .dts file (The specific Board configuration):  
   You include the .dtsi file and simply override the status for the ports you actually use.

#### example with status property

```ini, (SoC File: imx6.dtsi):
uart1: serial@02020000 {
    compatible = "fsl,imx6q-uart";
    reg = <0x02020000 0x4000>;
    status = "disabled"; // Disabled by default for safety
};
```

```ini, (Board File: my-custom-board.dts):
#include "imx6.dtsi"

&uart1 {
    status = "okay"; // Turned ON because this board physically uses UART1
};
```

### #address-cells and #size-cells

the **#address-cells** and **#size-cells** properties may be used in any device node that has children in the device tree hierarchy  
and describes how child device nodes should be addressed.  

1. The **#address-cells** property defines the number of `<u32>` cells used to encode the **address field** in a child node's **reg property**.
2. The **#size-cells**    property defines the number of `<u32>` cells used to encode the **size field**    in a child node's **reg property**.
3. The #address-cells and #size-cells properties are not inherited from ancestors in the devicetree. They shall be explicitly defined.
4. If missing, a client program should assume a default value of 2 for #address-cells, and a value of 1 for #size-cells.

### reg property

+ Property name: reg
+ Property value: `<prop-encoded-array>` encoded as an arbitrary number of (address, length) pairs.
+ Description: The reg property describes the address of the device’s resources within the address space defined by its parent bus.  
  Most commonly this means the offsets and lengths of memory-mapped IO register blocks, but may have a different meaning on some bus types.  
  Addresses in the address space defined by the root node are CPU real addresses.  
+ The value is a `<prop-encoded-array>`, composed of an arbitrary number of pairs of address and length, `<address length>`.  
  The number of `<u32>` cells required to specify the address and length are bus-specific and  
  are specified by the **#address-cells** and **#size-cells** properties in the parent of the device node.  
  If the parent node specifies a value of 0 for #size-cells, the length field in the value of reg shall be omitted.
+ The 'reg' property is the 7-bit I2C address.

**Example**: Suppose a device within a system-on-a-chip had 2 blocks of registers,  
The reg property would be encoded as follows (assuming #address-cells and #size-cells values of 1)

```ini
  reg = <0x3000 0x20 0xFE00 0x100>;
  // a  32-byte block at offset 0x3000 in the SOC and
  // a 256-byte block at offset 0xFE00.
```

### virtual-reg property

### ranges property

### dma-ranges property

### dma-coherent property

### dma-noncoherent property

## Interrupts and Interrupt Mapping

## pinctrl-bindings

### Introduction

Hardware modules that control pin multiplexing or configuration parameters such as  
**pull-up/down, tri-state, drive-strength** etc are designated as pin controllers.  
**Each pin controller must be represented as a node in device tree**, just like any other hardware module.  
Hardware modules whose signals are affected by pin configuration are designated client devices.  

For a client device to operate correctly, certain pin controllers must set up certain specific pin configurations.  

+ Some client devices need a single static pin configuration, e.g. set up during initialization.  
+ Others need to reconfigure pins at run-time, for example to tri-state pins when the device is inactive. 

Hence, each client device can define a set of named states.  
The number and names of those states is defined by the client device's own binding.  

The common pinctrl bindings defined in this file provide an infrastructure for client device device tree nodes  
to map those state names to the pin configuration used by those states.

Note that pin controllers themselves may also be client devices of themselves.  
For example, a pin controller may set up its own "active" state when the driver loads.  
This would allow representing a board's static pin configuration in a single place, rather than splitting it across multiple client device nodes.  
The decision to do this or not somewhat rests with the author of individual board device tree files,  
and any requirements imposed by the bindings for the individual client devices in use by that board,  
i.e. whether they require certain specific named states for dynamic pin configuration.

### Pinctrl client devices

For each client device individually, **every pin state is assigned an integer ID**.  
These numbers start at 0, and are contiguous.  
For each state ID, a unique property exists to define the pin configuration.  
Each state may also be assigned a name. When names are used, another property exists to map from those names to the integer IDs.  

Each client device's own binding determines the set of states that must be defined in its device tree node,  
and whether to define the set of state IDs that must be provided, or whether to define the set of state names that must be provided.

#### Required properties

+ **pinctrl-0**: List of phandles, each pointing at a pin configuration node.  
  These referenced pin configuration nodes must be child nodes of the pin controller that they configure.  
  Multiple entries may exist in this list so that multiple pin controllers may be configured,  
  or so that a state may be built from multiple nodes for a single pin controller,  
  each contributing part of the overall configuration.  

  In some cases, it may be useful to define a state, but for it to be empty.  
  This may be required when a common IP block is used in an SoC either without a pin controller,  
  or where the pin controller does not affect the HW module in question.  
  If the binding for that IP block requires certain pin states to exist, they must still be defined, but may be left empty.

+ Optional properties:
  + pinctrl-1: List of phandles, each pointing at a pin configuration node within a pin controller.
  + pinctrl-n: List of phandles, each pointing at a pin configuration node within a pin controller.
  + pinctrl-names: The list of names to assign states.  
    List entry 0 defines the name for integer state ID 0, list entry 1 for state ID 1, and so on.

## other things about pinctrl

The pinctrl (pin control) block in a Device Tree Source Include (.dtsi) file  
configures how physical SoC pins are routed, multiplexed, and electrically configured.  
Because modern MCU and SoCs have pins capable of multiple functions  
(e.g., a pin can act as a GPIO, an I2C data line, or a UART transmit line),  
the pinctrl subsystem manages these configurations cleanly across the Linux kernel or other real-time operating systems.

### 1. Key Components of a Pinctrl Block

A standard pinctrl setup consists of two main parts:

+ The Pin Controller Node: Defines the hardware registers and capabilities of the SoC's pin multiplexing hardware.
+ Pin Configuration Sub-nodes (States): Group specific pin configurations together, assigning them names like default, sleep, or active.

### 2. Example Structure in a DTSI File

```ini
/* SoC Pin Controller Definition */
soc {
    pinctrl: pin-controller@10000000 {
        compatible = "vendor,soc-pinctrl";
        reg = <0x10000000 0x1000>;

        /* Example pin group configuration for UART */
        uart0_pins: uart0-pins {
            pins = <15>, <16>;
            function = "uart0";
            bias-pull-up;
            drive-strength = <12>;
        };
    };
};

/* Peripheral Consumer Node (e.g., in a board .dts file) */
&uart0 {
    pinctrl-names = "default";
    pinctrl-0 = <&uart0_pins>;
    status = "okay";
};
```

### 3. Core Properties Explained

+ compatible: Identifies the specific driver required to handle the pin controller hardware.
+ pins / pinmux: Specifies the exact physical pin numbers or pin-multiplexing register values being configured.
+ function: Sets the alternate function mode for the selected pins (e.g., uart, spi, i2c).  
+ Electrical Properties: Configure internal resistances and signal characteristics, such as:
  + bias-pull-up / bias-pull-down
  + drive-strength (in milliamperes)
  + input-enable / output-high
+ pinctrl-names & pinctrl-0: Used by peripheral device nodes (like UART, I2C, or GPIO) to reference the pin states.  
  pinctrl-0 points to the default configuration group label.

### Summary

The pinctrl block acts as a bridge between abstract peripheral drivers and physical silicon wiring.  
By separating pin configuration from the device driver itself,  
it prevents conflicts and allows boards sharing the same SoC to reuse the core .dtsi file  
while customizing pin mappings in their specific .dts files.
