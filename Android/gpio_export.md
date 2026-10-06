# declare a GPIO

To declare a GPIO so that it can be controlled via the legacy `/sys/class/gpio/` interface running Android 14 (Linux kernel 5.10 or newer),  
you need to configure it in your device tree (dts/dtsi) file.

## Kernel Configuration Warning

Modern Android kernels (like Linux 5.10+) often disable the deprecated sysfs GPIO interface by default in favor of libgpiod.  
Ensure that CONFIG_GPIO_SYSFS=y is enabled in your kernel defconfig if /sys/class/gpio/ is missing entirely.

## 1. Identify the GPIO Bank and Pin

Find your target GPIO pin name from the RK3566 datasheet or schematic (e.g., GPIO0_PC6 or GPIO4_PB2).

+ Calculation: Bank 0 = 0, Bank 1 = 32, Bank 2 = 64, Bank 3 = 96, Bank 4 = 128.  
  For example, GPIO4_PB2 is Bank 4 (128) + Port B (8) + Pin 2 = 138.
+ Verification: Run cat /sys/kernel/debug/gpio on the device later to verify pin allocations.

## 2. Configure the GPIO in the Device Tree

Open your board's DTS file (typically located in arch/arm64/boot/dts/rockchip/rk3566-...dts)  
and define a pinctrl entry or use a hog if you want it exported automatically,  
or simply ensure it is not claimed by another conflicting driver (like serial, spi, or i2c).

If the pin is unused by other peripherals, you can declare it inside a dedicated gpio-keys or gpio-leds node,  
or ensure its pinctrl is set to default so it remains free for user-space export:

```ini
/ {
    user_gpio: user_gpio {
        compatible = "regulator-fixed"; // or generic dummy node if needed, or rely on pinctrl
        pinctrl-names = "default";
        pinctrl-0 = <&gpio4_b2_pins>; // Ensure your pinctrl is defined
    };
};
```

+ Verification: Compile the device tree (make dtbs) and flash the new boot/dtb image.

## 3. Export the GPIO from User Space

Once the system boots with the updated device tree,  
use the shell to export the GPIO number (e.g., 138) to the sysfs interface:  
`echo 138 > /sys/class/gpio/export`

+ Verification: Check that the directory `/sys/class/gpio/gpio138/` is created successfully.

## 4. Control Direction and Value

Configure the direction (input or output) and write values to test control:

```bash
echo out > /sys/class/gpio/gpio138/direction
echo 1 > /sys/class/gpio/gpio138/value
```

+ Verification: Read back the value or check the pin state with a multimeter:  
  `cat /sys/class/gpio/gpio138/value`

## configure

once a GPIO pin is exported and configured as an output,  
you can dynamically change its value between 0 (LOW) and 1 (HIGH) as many times as you want from user space.

### Write 1 to Value

+ Send a 1 to the pin's value file to drive the pin high (e.g., 3.3V):
  `echo 1 > /sys/class/gpio/gpio138/value`
+ Verification: Read back the value or check the pin with a multimeter to ensure it reads high:
  `cat /sys/class/gpio/gpio138/value`
