# comparison

The difference between declaring a pin as a **GPIO block** vs. an **LED**  
comes down to how you configure the Linux Kernel Device Tree (DTS/DTSI)  
and **which kernel subsystem handles the pin**.

Because Android relies on the underlying Linux kernel for hardware access,  
choosing how you declare a pin changes how **user-space apps or system services** interact with it.

## 1. Declaring a Pin as a GPIO Block on RK3566

When you declare a pin as raw GPIO in the RK3566 device tree,  
you are asking the Rockchip **`pinctrl driver`** (pinctrl-rockchip)  
to map a physical package ball to a **software-controllable digital line**.

+ Under the hood (RK3566 Architecture): RK3566 has 5 GPIO banks (`GPIO0` to `GPIO4`), each with pins split into groups A0–D7.
+ Device Tree Implementation: You define it using Rockchip's internal macros (`RK_PA0` through `RK_PD7`).

```ini
// Example: Configuring a raw GPIO pin (e.g., GPIO4_D5) in DTS pinctrl
&pinctrl {
    my_gpio_pins: my-gpio-pins {
        rockchip,pins = <4 RK_PD5 RK_FUNC_GPIO &pcfg_pull_none>;
    };
};
```

+ Android / Linux User-Space Interface:
  + **Exposed via generic sysfs** (`/sys/class/gpio/`) or character devices (`/dev/gpiomem`).  
  + To toggle it from an ADB shell or a **native Android HAL service**,  
    you manually calculate its global GPIO number (e.g., GPIO4_D5 = 4*32 + 3*8 + 5 = 157), export it,  
    and write 1 or 0 to its value file.

```bash
echo 157 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio157/direction
echo 1 > /sys/class/gpio/gpio157/value
```

+ Use case: Custom hardware controls, general-purpose input buttons, chip-enable lines for external SPI/I2C chips, or proprietary sensors.

## 2. Declaring a Pin as an LED on RK3566

When you declare a pin as an LED on RK3566,  
you use the **standard Linux GPIO LED driver** (`compatible = "gpio-leds"`).

+ Under the hood:
  The kernel wraps the raw GPIO block inside the LED subsystem.  
  It abstracts away raw digital logic and introduces semantic concepts like `brightness`, `triggers` (heartbeat, timer, default-on), and inversions.
+ Device Tree Implementation:

```ini
// Example: Declaring an LED driven by a specific GPIO on RK3566
gpio-leds {
    compatible = "gpio-leds";

    status_led {
        label = "status_led";
        gpios = <&gpio4 RK_PD5 GPIO_ACTIVE_HIGH>;
        default-state = "on";
    };
};
```

+ Android / Linux User-Space Interface:
  + **Exposed via the LED class** subsystem under `/sys/class/leds/status_led/`.
  + You don't deal with directions or raw bit math.  
    Instead, user-space tools or system scripts control it via triggers and brightness:
+ Use case: Status LEDs, power lights, charging indicators, or debugging blinks.

## Quick Comparison for RK3566 Android Development

### Feature: GPIO Block (pinctrl / gpio-keys / custom driver)

+ Kernel Subsystem: `drivers/gpio/` or `pinctrl-rockchip`
+ User-space Path: `/sys/class/gpio/gpioXXX`
+ Control Parameters: Direction (in/out), Value (0/1)
+ Best Suited For: Relays, level shifters, general input/output lines, buttons

### Feature: LED Subsystem (gpio-leds)

+ Kernel Subsystem: `drivers/leds/leds-gpio.c`
+ User-space Path: `/sys/class/leds/<led_name>/`
+ Control Parameters: Brightness, Triggers (heartbeat, timer, none)
+ Best Suited For: Status lights, power/activity feedback indicators

## Recommendation

If the pin is physically connected to an LED component on your RK3566 board layout, always declare it as a GPIO LED (gpio-leds).  
It saves you from writing custom Android HAL code or manual file-system scripts just to make an indicator light blink,  
because the standard Linux LED triggers can handle system events out-of-the-box.
