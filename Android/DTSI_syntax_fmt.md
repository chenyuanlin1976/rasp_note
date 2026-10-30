# DTSI: syntax format

DTSI stands for Device Tree Source Include.  
It uses the Devicetree Source (DTS) syntax -  
a specialized, human-readable structural format designed specifically by the Power.org (formerly PowerPC) architecture committee  
and later adopted by ARM and Linux to describe hardware topologies.

It shares some visual similarities with JSON (like using braces {} and key-value pairs),  
but its actual roots look much closer to a C-style header file combined with hierarchical tree structures.

## 1. Key Characteristics of DTSI Syntax

+ Hierarchical Tree: Hardware components are described as nested nodes, representing buses, controllers, and devices.
+ Includable (.dtsi): Just like a C header file (.h),  
  a .dtsi file contains reusable hardware descriptions (like a standard SoC architecture) that get included into a top-level .dts board file  
  using the `#include` directive.
+ Properties: Devices have properties defined as `key = <value>;` or `key = "string";`.
+ Semicolons Required: Unlike JSON, almost every property line and node block must end with a semicolon `;`.

## 2. Example DTSI Syntax Structure

Here is what a typical .dtsi snippet looks like:

```ini
/ {
    // A root node containing SoC-level peripherals
    soc: soc {
        compatible = "simple-bus";
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        // UART controller node
        uart0: serial@10000000 {
            compatible = "ns16550a";
            reg = <0x10000000 0x100>;
            interrupts = <4>;
            clocks = <&uart_clk>;
            status = "disabled"; // Can be enabled in the final device board DTS
        };
    };
};
```

## 3. What Happens to a DTSI File

Just like source code, a DTSI file isn't read directly by the Linux kernel at runtime.

1. It gets merged with a board-specific .dts file via the C Preprocessor (cpp).
2. The Device Tree Compiler (dtc) compiles the merged text file into a binary format called a DTB (Device Tree Blob) (.dtb).
3. The bootloader passes this .dtb blob to the Linux kernel during boot so the kernel knows what hardware exists on the board.
