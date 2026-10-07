# device tree node: &leds

In the context of your Linux kernel source or device tree source (.dts/.dtsi), &leds is a device tree node reference label.

It points to the main LED controller block (usually defined as `compatible = "gpio-leds"`)  
so that you can add, configure, or override individual LED definitions (like your sys_led_r) for specific hardware targets.

## What It Controls

+ Hardware GPIO Lines: It maps a logical LED name (like `sys_led_r`) to a physical SoC General Purpose Input/Output (GPIO) pin.
+ Initial and Trigger States: It controls default configurations, such as whether the LED turns on automatically at boot  
  or stays bound to specific kernel triggers (like heartbeat, timer, or manual user-space control).

## Troubleshooting Steps for LED Control

### 1.Check Device Tree Definition

+ Locate your board's .dts file and verify that the &leds block correctly references your hardware GPIO pin and has proper polarity.
+ Verification: Run `adb shell cat /sys/kernel/debug/gpio`  
  to check if the target GPIO pin assigned to your LED is exported and configured as an output.

### 2.Check Sysfs Node Generation

+ Verify that the kernel successfully created the sysfs directory for your LED based on the device tree configuration.
+ Verification: Run `adb shell ls -l /sys/class/leds/` to confirm sys_led_r appears in the list.

## Blinking

standard gpio-leds device tree nodes do **NOT** include direct configuration properties for `delay_on` or `delay_off`.

The device tree only supports properties like `gpios`, `default-state`, and `linux,default-trigger`.  
To configure **blinking** behavior with specific delays,  
you set the `default trigger` to `timer` in the device tree and then configure the delay values dynamically.

### How to Configure Blinking via Device Tree and Init

#### 1.Set the default trigger to timer

+ Add `linux,default-trigger = "timer"` to your LED sub-node in the .dts file:
+ Verification: Check that the node compiles without errors and the kernel creates the trigger file.

```inicompatible
leds {
    compatible = "gpio-leds";
    sys_led_r {
        label = "sys_led_r";
        gpios = <&gpio1 2 GPIO_ACTIVE_HIGH>;
        linux,default-trigger = "timer";
        default-state = "off";
    };
};
```

#### 2.Configure delay times at boot

Since delays cannot be hardcoded in the device tree,  
write your desired millisecond values to the sysfs nodes via an `init.rc` script or custom service right after boot:

```bash
write /sys/class/leds/sys_led_r/trigger timer
write /sys/class/leds/sys_led_r/delay_on 500
write /sys/class/leds/sys_led_r/delay_off 500
```

+ Verification: Run adb shell cat /sys/class/leds/sys_led_r/delay_on to verify the value matches what you configured.
