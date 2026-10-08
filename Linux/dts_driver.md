# dtsi and driver

In Linux, the Device Tree Source Include (`.dtsi`) file and device drivers work together  
through a structured mechanism that decouples hardware description from driver logic.

## 1. The Role of .dtsi vs. .dts

+ .dtsi (Device Tree Source Include): Acts like a header file for hardware.  
  It describes reusable, core hardware blocks built into the SoC (System on Chip) - such as CPU cores, internal timers, UARTs, I2C controllers, and memory maps.  
  Peripherals inside a .dtsi are often marked with status = "disabled" by default.
+ .dts (Device Tree Source): Represents the specific board.  
  It #includes the SoC's .dtsi file, enables only the peripherals actually wired out on that board (status = "okay"),  
  and configures board-specific external components (like sensors, PMICs, or touch controllers).

## 2. How Drivers Connect to the Device Tree

The connection between the Linux driver and the hardware described in the .dtsi/.dts happens via a few key steps:

### Step A: Compilation (.dts/.dtsi to .dtb)

The Device Tree Compiler (dtc) compiles all included `.dtsi` and `.dts` files into a single binary file called a Device Tree Blob (`.dtb`).  
*The bootloader loads this .dtb into RAM and passes its memory address to the Linux kernel at boot time.*

### Step B: The compatible String Matching

Every hardware node inside a .dtsi or .dts file has a **compatible** property.  
Linux drivers declare a matching table of strings they support.

```ini
# In the Device Tree (.dtsi node example
i2c1: i2c@5000 {
    compatible = "vendor,soc-i2c";
    reg = <0x00005000 0x1000>;
    interrupts = ;
    status = "disabled"; /* Enabled later in the board .dts */
};
```

```c
// In the Linux Driver (.c file)
static const struct of_device_id my_i2c_dt_ids[] = {
    { .compatible = "vendor,soc-i2c", .data = &soc_i2c_cfg },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, my_i2c_dt_ids);

static struct platform_driver my_i2c_driver = {
    .probe = my_i2c_probe,
    .driver = {
        .name = "my-i2c-driver",
        .of_match_table = my_i2c_dt_ids,
    },
};
```

When the kernel boots and parses the Device Tree, it scans all nodes with `status = "okay"`.  
If a node's compatible string matches an entry in the driver's `of_match_table`, the kernel triggers that driver's probe() function.

## Step C: Extracting Configuration Data in the probe() Function

Once the driver's `.probe()` function is called, it receives a pointer to the device structure (`struct platform_device *pdev`).  
The driver then queries the Device Tree data (originally defined in the .dtsi or .dts) to extract configuration parameters  
like memory addresses, interrupts, or custom properties using standard kernel APIs:

+ Registers (`reg`): Retrieved using platform_get_resource(pdev, IORESOURCE_MEM, 0) to map physical memory addresses.
+ Interrupts (`interrupts`): Retrieved using `platform_get_irq(pdev, 0)`.
+ Custom Properties: Extracted using helper functions like `of_property_read_u32()` or `of_get_named_gpio()`.

## Summary Workflow

1. Define SoC hardware components inside the .dtsi file.
2. Override/Enable them for your specific hardware in the .dts file.
3. Compile them into a .dtb binary passed by the bootloader.
4. Match the node's `compatible` string with the driver's match table.
5. Fetch hardware configurations (registers, clocks, pins) dynamically inside the driver's `probe()` function.
