# Device tree, kernel drivers, and a user-space HAL on Linux

On embedded Linux, a `.dts`/`.dtsi` file and a Hardware Abstraction Layer (HAL) work at **different levels**:

+ The **device tree** describes the hardware **to the kernel**.
+ A **user-space HAL** abstracts the kernel's interfaces **for applications**.

They never talk to each other directly.
The **kernel driver** sits between them: it reads the device tree and exposes `/sys` or `/dev` files that the HAL uses.

## 1. The device tree (`.dts` / `.dtsi`)

+ **What it is**: a hardware **description**, data rather than code.
  It lists which devices exist, their register addresses (`reg`), interrupts, clocks, GPIO wiring, and pin muxing.
+ **`.dtsi`** (include): the SoC-level description, usually from the chip vendor (e.g. `imx6qdl.dtsi`, `rk3566.dtsi`).
  Many peripherals are defined there with `status = "disabled"`.
+ **`.dts`** (board): includes the `.dtsi`, enables what the board actually uses, and adds board-level devices such as LEDs, regulators, and sensors on I2C.
+ **Build/boot**: `dtc` compiles it into a **`.dtb`**. The bootloader (U-Boot, ...) loads the `.dtb` and passes it to the kernel,
  optionally with **overlays** (`.dtbo`).
+ On a running system: `/proc/device-tree/` (or `/sys/firmware/devicetree/base/`).

## 2. What "HAL" means on Linux

Linux itself has **no single HAL layer**. In the kernel, hardware is abstracted by **driver subsystems**
(gpiolib, the LED class, IIO, input, V4L2, ALSA, ...), each with a standard user-space interface.
A "HAL" on Linux is usually a **user-space library or daemon** on top of those interfaces.
Examples:

+ Android HALs (camera, lights, sensors) in their own processes, called over Binder.
  See [../Android/HAL_intro.md](../Android/HAL_intro.md).
+ Middleware in a product (an `ILed`/`IGpio` C++ library, a hardware daemon with a D-Bus API).
+ Libraries such as libgpiod, libiio, or libcamera, which wrap one subsystem.

## 3. The chain

```text
board.dts + soc.dtsi --dtc--> board.dtb --bootloader--> kernel
                                                          | matches "compatible" -> probes drivers
                                                          v
                                   kernel driver (gpio-leds, gpio controller, ...)
                                                          | exposes standard interfaces
                                                          v
                                   /sys/class/leds/<name>/brightness, /dev/gpiochipN, /dev/i2c-N, ...
                                                          | open/read/write/ioctl
                                                          v
                                   user-space HAL (C/C++ library or daemon)
                                                          | clean API: led.turnOn()
                                                          v
                                   application
```

## 4. Example: a status LED

### Step 1: Device tree

The SoC `.dtsi` (from the vendor) defines the GPIO controller.
The fragment below is shortened, in the style of i.MX6 `gpio1`:

```dts
/* soc.dtsi (fragment) */
#include <dt-bindings/interrupt-controller/arm-gic.h>

soc {
    gpio1: gpio@209c000 {
        compatible = "fsl,imx6q-gpio", "fsl,imx35-gpio";
        reg = <0x0209c000 0x4000>;
        interrupts = <GIC_SPI 66 IRQ_TYPE_LEVEL_HIGH>,
                     <GIC_SPI 67 IRQ_TYPE_LEVEL_HIGH>;
        gpio-controller;
        #gpio-cells = <2>;
        interrupt-controller;
        #interrupt-cells = <2>;
    };
};
```

The board `.dts` wires an LED to GPIO1 pin 4, using the generic **`gpio-leds`** driver:

```dts
/* board.dts */
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/leds/common.h>
#include "soc.dtsi"

/ {
    leds {
        compatible = "gpio-leds";

        led-status {
            label = "system_status";               /* -> /sys/class/leds/system_status */
            gpios = <&gpio1 4 GPIO_ACTIVE_HIGH>;   /* controller, pin, flags */
            default-state = "off";
            linux,default-trigger = "none";        /* e.g. "heartbeat", "mmc0" */
        };
    };
};
```

With `CONFIG_LEDS_GPIO` enabled, the `gpio-leds` driver probes this node at boot and creates `/sys/class/leds/system_status/`
(with `brightness`, `max_brightness`, `trigger`).
The pin also has to be muxed as GPIO, which needs a `pinctrl` entry on most SoCs (see [dts_conventions.md](dts_conventions.md)).
Newer bindings prefer `function = LED_FUNCTION_STATUS;` and `color = <LED_COLOR_ID_GREEN>;` to `label`;
the kernel then builds the name, for example `green:status`.

You can test it from a shell before writing any code:

```shell
cat /sys/class/leds/system_status/max_brightness       # 1 for a GPIO LED
echo 1 | sudo tee /sys/class/leds/system_status/brightness
echo heartbeat | sudo tee /sys/class/leds/system_status/trigger
```

### Step 2: The C++ HAL in user space

The application shouldn't know about `/sys` paths.
The HAL interface describes *what* an LED can do. The design pattern (interfaces, dependency injection, mocks) is explained in [HAL_intro.md](HAL_intro.md).

```c++
// ILed.h
class ILed {
  public:
    virtual ~ILed() = default;
    virtual bool turnOn() = 0;      // false on failure: hardware access can fail
    virtual bool turnOff() = 0;
    virtual bool isOn() const = 0;
};
```

```c++
// SysfsLed.h: Linux implementation on top of the LED class driver
#include <fstream>
#include <string>
#include "ILed.h"

class SysfsLed : public ILed {
  public:
    explicit SysfsLed(const std::string& name)
        : dir_("/sys/class/leds/" + name + "/") {
        std::ifstream f(dir_ + "max_brightness");
        if (!(f >> max_)) max_ = 1;
    }

    bool turnOn() override  { return write("brightness", std::to_string(max_)); }
    bool turnOff() override { return write("brightness", "0"); }   // also stops any trigger

    bool isOn() const override {
        std::ifstream f(dir_ + "brightness");
        int v = 0;
        return (f >> v) && v > 0;    // PWM LEDs report 0..max_brightness, not just 0/1
    }

  private:
    bool write(const char* attr, const std::string& value) const {
        std::ofstream f(dir_ + attr);
        f << value;
        f.flush();
        return static_cast<bool>(f);  // false if open or write failed (e.g. EACCES)
    }

    std::string dir_;
    int max_ = 1;
};
```

### Step 3: The application

```c++
#include <cstdio>
#include "SysfsLed.h"

class SystemMonitor {
  public:
    explicit SystemMonitor(ILed& led) : statusLed_(led) {}
    void onSystemError() {
        if (!statusLed_.turnOn()) std::fprintf(stderr, "status LED unavailable\n");
    }
  private:
    ILed& statusLed_;   // depends only on the interface
};

int main() {
    SysfsLed boardLed("system_status");   // the only line that knows it's Linux + this LED name
    SystemMonitor monitor(boardLed);
    monitor.onSystemError();
}
```

Permissions: writing `brightness` needs root by default.
Give a non-root service access with a **udev rule**, for example
`SUBSYSTEM=="leds", KERNEL=="system_status", RUN+="/bin/chgrp leds /sys%p/brightness", RUN+="/bin/chmod g+w /sys%p/brightness"`,
or run the HAL as a small privileged daemon.

## 5. Summary

1. **`.dtsi`/`.dts` → `.dtb`** tell the kernel: "there is an LED on GPIO1 pin 4."
2. The **`gpio-leds` driver** binds to the node and exposes `/sys/class/leds/system_status/`.
3. The **user-space HAL** (`SysfsLed`) wraps that file in `turnOn()`/`turnOff()`.
4. The **application** uses `ILed` and knows nothing about the device tree, drivers, or paths.
   Porting to another board changes the `.dts` (and maybe the LED name), not the application.

## Related notes

+ [HAL_intro.md](HAL_intro.md): C++ HAL design
+ [HAL_mmio_vs_sysfs.md](HAL_mmio_vs_sysfs.md): why the HAL uses kernel interfaces, not `/dev/mem`
+ [dts_intro.md](dts_intro.md), [dts_node_leds.md](dts_node_leds.md), [dts_conventions.md](dts_conventions.md), [dts_driver.md](dts_driver.md)

## Reference

+ [Devicetree usage (kernel docs)](https://docs.kernel.org/devicetree/usage-model.html)
+ [LED class (kernel docs)](https://docs.kernel.org/leds/leds-class.html)
+ [gpio-leds binding (leds-gpio.yaml)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/leds/leds-gpio.yaml)
