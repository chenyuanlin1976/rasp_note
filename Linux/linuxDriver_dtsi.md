# linux driver and .dtsi

The interaction between a Linux driver and a Device Tree Source Include (.dtsi) file is the foundation  
of how the kernel understands and communicates with non-discoverable hardware (such as SoC peripherals, GPIOs, and I2C devices).

Here is a step-by-step breakdown of how this process works from boot to driver execution:

## 1. Hardware Description (The DTSI File)

A .dtsi file is a reusable template containing hierarchical nodes  
that describe the physical hardware layout of a System-on-Chip (SoC). It defines:

+ Memory-mapped register addresses (`reg`)
+ Interrupt lines (`interrupts`)
+ Clock and power sources
+ A unique `compatible` string that acts as an ID card for the hardware block.

```ini, Example snippet from a .dtsi file
my_device: timer@12345000 {
    compatible = "vendor,my-timer-v1";
    reg = <0x12345000 0x1000>;
    interrupts = <0 48 4>;
};
```

## 2. The Compilation and Boot Process

+ Compilation: The .dts (Device Tree Source) and its included .dtsi files are compiled by the Device Tree compiler (dtc)  
  into a binary format called a Device Tree Blob (.dtb).
+ Loading: The bootloader (like U-Boot) loads the .dtb file into the target system's memory  
  and passes its memory address to the Linux kernel upon startup.
+ Unflattening: The kernel parses this binary blob during early boot into an in-memory database of nodes  
  and properties called the flattened device tree (FDT).

## 3. Driver Matching (The Bridge)

Linux drivers (specifically Platform Drivers) register themselves with the kernel  
and specify which hardware they support using an `of_device_id table` containing `compatible` strings.

+ When the kernel "unflattens" the device tree, it scans every node.
+ It compares a node's `compatible` string (e.g., "vendor,my-timer-v1") with the compatible strings registered by loaded drivers.
+ When a match is found, the kernel creates a `platform_device` representation in memory and binds it to your platform_driver.

## 4. Probing and Extracting Configuration

Once matched, the kernel executes the driver's `probe()` function.  
Inside this function, the driver queries the Device Tree node to pull its specific configuration values using Open Firmware (of_) API helper functions.

+ Getting Registers: `platform_get_resource()` or `devm_ioremap_resource()` maps the physical addresses defined in the `reg` property into virtual memory.
+ Getting Interrupts: `platform_get_irq()` fetches the interrupt line.
+ Reading Custom Properties: Functions like `of_property_read_u32()` or `of_get_named_gpio()` extract custom configuration parameters  
  defined in the .dtsi or board .dts file.

```c, Example driver code snippet
static int my_driver_probe(struct platform_device *pdev) {
    struct device *dev = &pdev->dev;
    void __iomem *base;
    u32 val;

    // Maps the 'reg' resource from the DTSI
    base = devm_platform_ioremap_resource(pdev, 0);
    
    // Reads a custom property if defined in the DT
    if (of_property_read_u32(dev->of_node, "my-custom-config", &val)) {
        val = 100; // Default fallback value
    }

    return 0;
}

static const struct of_device_id my_driver_dt_match[] = {
    { .compatible = "vendor,my-timer-v1" },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, my_driver_dt_match);
```

## GPIO pin control

Linux drivers recognize and control GPIO pins (such as those used for power rails, resets, or chip enables)  
through a **standardized convention** between the Device Tree and the GPIO Consumer API in the kernel.

This process relies on descriptive property naming suffixes and specific kernel helper functions.

### 1. Defining the GPIO in the DTSI File

In your .dtsi file, the peripheral node includes a property ending in `-gpios` (or `-gpio`).  
This property points to a specific pin on a GPIO controller and defines its active state (e.g., active high or active low).

```ini, Example DTSI Snippet
my_device: sensor@68 {
    compatible = "vendor,my-sensor";
    reg = <0x68>;
    
    /* Defines a GPIO named "enable" tied to gpio controller bank 1, pin 12, active high */
    enable-gpios = <&gpio1 12 GPIO_ACTIVE_HIGH>;
    power-gpios = <&gpio2 5 GPIO_ACTIVE_LOW>;
};
```

+ &gpio1: A reference to the SoC's GPIO controller node.
+ 12: The specific pin index on that controller.
+ GPIO_ACTIVE_HIGH: Flags defining polarity.

### 2. Requesting the GPIO in the Driver

Inside the driver's `probe()` function, the kernel uses the **GPIO Descriptor API** (`gpiod_*`) to find and claim the pin.

When you pass a string like "enable" to the lookup function,  
the kernel automatically appends `-gpios` (or `-gpio`) and searches the device's **DT node** for a matching property.

+ `devm_gpiod_get(dev, "enable", GPIOD_OUT_HIGH)`: Requests the pin, configures it as an output, and sets it to an initial high state.
+ `devm_gpiod_get_optional(...)`: Useful if the pin is optional on some board designs;  
  returns `NULL` if the property isn't in the Device Tree instead of failing.
+ `devm_ prefix`: Means the GPIO is managed automatically—when the driver is unloaded or unbound, the kernel automatically releases the pin.

### 3. Controlling the Pin in Code

Once the driver has a **handle** to the **GPIO descriptor** (`struct gpio_desc *`),  
it can control the hardware state cleanly without needing to know the physical pin number or register address.

```c, Example Driver Code
struct gpio_desc *enable_gpio;

static int my_driver_probe(struct platform_device *pdev) {
    struct device *dev = &pdev->dev;

    // 1. Request the "enable-gpios" property from the Device Tree
    enable_gpio = devm_gpiod_get_optional(dev, "enable", GPIOD_OUT_HIGH);
    if (IS_ERR(enable_gpio)) {
        return PTR_ERR(enable_gpio);
    }

    // 2. If present, use it to power on or enable the hardware
    if (enable_gpio) {
        // Sets the pin high (respecting the polarity defined in DT)
        gpiod_set_value(enable_gpio, 1);
        
        // Optional: add a small delay if the hardware needs time to stabilize
        usleep_range(1000, 2000);
    }

    return 0;
}
```

### Why this approach is powerful

Polarity Abstraction: If a hardware revision changes an enable pin from active-high to active-low, you only change it in the **.dts/.dtsi** file.  
The driver code (`gpiod_set_value(gpio, 1)`) remains completely unchanged because the kernel handles the inversion logic automatically based on the DT flag.
