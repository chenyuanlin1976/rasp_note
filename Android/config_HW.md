# config HW

## config GPIO

To compile an Android image with a GPIO configured as an output pin  
or to ensure your custom board configuration supports it at the kernel level,  
you need to modify the **Android Device Tree (DTS/DTSI)** source files  
before building the AOSP (Android Open Source Project) source tree.

Here are the steps to configure and compile your Android system image with custom GPIO support:

### Step 1: Modify the Device Tree (DTS/DTSI)

GPIO definitions are typically handled by the Linux kernel via the Device Tree.

+ Navigate to your device-specific kernel or device tree directory in your Android source tree  
  (commonly found under `device/<vendor>/<board>/kernel-headers/` or your external kernel repository).
+ Locate your board's .dts or .dtsi file.
+ Define or configure the GPIO pin under the appropriate GPIO controller node. For example:

```ini
// Example Device Tree snippet for a GPIO output pin
gpio_pins {
    compatible = "pin-controller-example";
    my_custom_output: custom_output_pin {
        pins = <GPMC_A2 (PIN_OUTPUT | PULL_DISABLE)>; // Adjust architecture syntax accordingly
        mux-setting = <0>;
    };
};
```

### Step 2: Enable Kernel Config Options

Ensure that your kernel configuration (**defconfig**) includes the necessary drivers for GPIO support and character devices:

+ Open your kernel configuration file (e.g., `arch/arm64/configs/myboard_defconfig`).
+ Verify or add the following flags:

```ini
CONFIG_GPIOLIB=y
CONFIG_GPIO_CDEV=y
CONFIG_GPIO_SYSFS=y (optional, if legacy sysfs support is needed)
```

### Step 3: Build the Android Image

Once your device tree and kernel configuration are updated, follow the standard AOSP build steps:

1. Initialize the Build Environment:  
   Environment Setup.Source the envsetup script and choose your target device configuration.

```bash
source build/envsetup.sh
lunch <your_device_target>-userdebug
```

2. Build the Kernel and Android Image:  
   Compile the complete Android image, including the customized boot/kernel image containing your updated device tree.
