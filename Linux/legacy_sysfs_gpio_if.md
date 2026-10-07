# legacy sysfs GPIO interface

The legacy sysfs GPIO interface (`/sys/class/gpio/`) operates entirely **independently** of  
the modern Linux Pin Control (`pinctrl`) and Device Tree subsystems.

When you export a pin via `/sys/class/gpio/export`, the kernel's old **gpiolib** handles the request by talking directly to the GPIO controller driver,  
bypassing any sophisticated pin multiplexing (`pinctrl`) configuration defined in your .dtsi file unless specific conditions are met.

## How They Interact (and Where They Clash)

1. The Role of Pinctrl (Device Tree):  
   When the kernel boots, the `pinctrl` driver parses your .dtsi file and configures the physical pin's multiplexer (mux)  
   so it is routed to the GPIO block instead of an alternate function like SPI, I2C, or UART. It also sets up initial pull-ups/pull-downs.
2. The Role of /sys/class/gpio/export:  
   When you echo a pin number to `/sys/class/gpio/export`, the generic GPIO subsystem requests that specific pin from the GPIO chip driver.
3. The Potential Conflict:
   + If pinctrl configured the pin properly: Exporting the GPIO will succeed, and you can control its value (direction, value) via `sysfs`.
   + If the pin is claimed by another driver: If a modern driver (like a kernel SPI or LED driver) has already claimed that GPIO  
     via the GPIO descriptor API (`gpiod_get`), the kernel will **block the sysfs export** to prevent hardware conflicts.
   + The Legacy Limitation: Sysfs GPIO knows nothing about modern consumer labels, power regulators, or active-low inversions defined in the Device Tree.  
     It operates strictly on raw global GPIO chip base offsets and numerical IDs.

## Why Sysfs GPIO is Deprecated

The `/sys/class/gpio/` interface has been officially deprecated in the Linux kernel  
in favor of the character device interface (`/dev/gpiochipN` used by gpiod tools).  
Sysfs lacks proper handling for pin polarity, doesn't integrate cleanly with the modern **pinctrl framework**,  
and can leave pins in unsafe states if user-space applications crash.
