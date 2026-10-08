# common standardized conventions

The Linux kernel enforces strict naming and structural conventions for Device Tree Source (.dts/.dtsi) files.  
These standardized conventions allow generic kernel subsystems (like GPIO, clocks, power, and interrupts)  
to automatically parse hardware parameters without needing custom parsing logic written for every single driver.

The most common standardized conventions used across Linux drivers include:

## 1. Resource & Naming Suffixes

Linux subsystems look for specific suffixes attached to property names to identify the resource type:

| Suffix/Property | Subsystem/ Purpose                        | Example in DTSI                              |
| --------------- | ----------------------------------------- | -------------------------------------------- |
| -gpios/-gpio    | GPIO Pins (enables, resets, chip-selects) | enable-gpios = <&gpio1 12 GPIO_ACTIVE_HIGH>; |
| -supply         | Regulators (Power Rails / LDOs)           | vmmc-supply = <&ldo3_reg>;                   |
| -clocks         | Input Clock sources                       | clocks = <&ccu CLK_BUS>;                     |
| -resets         | Hardware Reset lines                      | resets = <&rst 0>;                           |
| -names          | Labels matching multi-resource arrays     | clock-names = "bus", "functional";           |

## 2. Core Standard Properties

Every device node relies on a few mandatory or universally recognized properties defined by the Device Tree specification.

+ `compatible`: Links the hardware node to its corresponding Linux device driver  
  using a "vendor,model" format (e.g., `compatible = "ti,am3352-rtc"`).
+ `reg`: Defines the physical memory-mapped register address space (address and size).
+ `interrupts`/ interrupt-parent: Specifies which hardware interrupt line the device triggers and which interrupt controller manages it.
+ `status`: Controls whether the device is active or disabled.  
  Setting `status = "disabled"`; tells the kernel to ignore the node entirely.

## 3. Pin Control (pinctrl) Convention

Before a driver can use a pin for a specific function (like UART RX/TX or a high-speed SPI bus),  
the pin multiplexer must be configured. Linux standardizes this via **pinctrl**:

```ini, DTS
my_device: device@12340000 {
    compatible = "vendor,my-device";
    reg = <0x12340000 0x1000>;
    
    /* Defines names for pin configuration states */
    pinctrl-names = "default", "sleep";
    /* Points to pin configurations defined elsewhere in the DTSI */
    pinctrl-0 = <&my_device_pins_active>;
    pinctrl-1 = <&my_device_pins_sleep>;
};
```

+ `pinctrl-names`: Usually contains "default" (**active operating state**) and optionally "sleep" (**low-power state**).
+ `pinctrl-0`, `pinctrl-1`, etc.: **Phandles** pointing to the exact electrical configurations (pull-ups, slew rate, drive strength)  
   *managed automatically by the kernel's pinctrl subsystem before the driver's probe() runs*.

## 4. Power Management & Regulators Convention

Instead of controlling a power rail directly through a GPIO line,  
modern hardware often routes power through a Power Management IC (PMIC) managed by the Linux **Regulator Framework**:

+ In the DTSI, power inputs use the `-supply` suffix (e.g., `vdd-supply = <&pmic_reg1>;`).
+ In the driver, instead of manually toggling a GPIO, the driver author calls generic kernel functions  
  like `devm_regulator_get(dev, "vdd")` and `regulator_enable()`.  
  The kernel handles sequencing and voltage scaling transparently.
