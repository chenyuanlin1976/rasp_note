# HAL design in C++

A **Hardware Abstraction Layer (HAL)** separates *what* the application wants from the hardware
("drive this pin high", "send these bytes") from *how* a particular chip or OS does it
(registers, vendor SDK calls, `/sys` files, ioctls).

Classic C HALs do this with **function-pointer structs** and macros. Android's old `libhardware` modules
and many vendor SDKs work that way.
A C++ HAL uses **interfaces, polymorphism, and templates** for the same goal, with stronger typing.

The same design works on a microcontroller (implemented with the vendor HAL; see [HAL_Std_Func.md](HAL_Std_Func.md))
and on embedded Linux (implemented with kernel interfaces; see [HAL_DeviceTree.md](HAL_DeviceTree.md)).

## 1. Interface: what a peripheral does

```c++
// IGpioPin.h: a digital output/input pin, independent of any chip
class IGpioPin {
  public:
    virtual ~IGpioPin() = default;
    virtual void setHigh() = 0;
    virtual void setLow() = 0;
    virtual void toggle() = 0;
    virtual bool read() const = 0;
};
```

## 2. Implementations: how each platform does it

### 2.1 STM32 (vendor HAL, bare metal)

```c++
#include "stm32f4xx_hal.h"
#include "IGpioPin.h"

class Stm32GpioPin : public IGpioPin {
  public:
    Stm32GpioPin(GPIO_TypeDef* port, uint16_t pinMask) : port_(port), pin_(pinMask) {}   // e.g. GPIOC, GPIO_PIN_13

    void setHigh() override    { HAL_GPIO_WritePin(port_, pin_, GPIO_PIN_SET); }
    void setLow() override     { HAL_GPIO_WritePin(port_, pin_, GPIO_PIN_RESET); }
    void toggle() override     { HAL_GPIO_TogglePin(port_, pin_); }
    bool read() const override { return HAL_GPIO_ReadPin(port_, pin_) == GPIO_PIN_SET; }

  private:
    GPIO_TypeDef* port_;
    uint16_t pin_;
};
```

What `HAL_GPIO_WritePin` does at the register level is shown in [../Android/HAL_STM32_example.md](../Android/HAL_STM32_example.md).

### 2.2 Embedded Linux (libgpiod v1, character device)

```c++
#include <gpiod.h>
#include <stdexcept>
#include "IGpioPin.h"

class LinuxGpioPin : public IGpioPin {
  public:
    LinuxGpioPin(const char* chip, unsigned offset) {             // e.g. "gpiochip0", 13
        chip_ = gpiod_chip_open_by_name(chip);
        if (!chip_) throw std::runtime_error("open chip failed");
        line_ = gpiod_chip_get_line(chip_, offset);
        if (!line_ || gpiod_line_request_output(line_, "cpp-hal", 0) < 0) {
            gpiod_chip_close(chip_);
            throw std::runtime_error("request line failed");    // e.g. EBUSY: a driver owns it
        }
    }
    ~LinuxGpioPin() override { gpiod_line_release(line_); gpiod_chip_close(chip_); }
    LinuxGpioPin(const LinuxGpioPin&) = delete;                  // owns OS resources: no copies
    LinuxGpioPin& operator=(const LinuxGpioPin&) = delete;

    void setHigh() override    { gpiod_line_set_value(line_, 1); }
    void setLow() override     { gpiod_line_set_value(line_, 0); }
    void toggle() override     { gpiod_line_set_value(line_, !read()); }
    bool read() const override { return gpiod_line_get_value(line_) == 1; }

  private:
    gpiod_chip* chip_ = nullptr;
    gpiod_line* line_ = nullptr;
};
```

See [libgpiod_intro.md](libgpiod_intro.md). libgpiod v2 uses a different API.

### 2.3 Mock (host unit tests)

```c++
class MockGpioPin : public IGpioPin {
  public:
    void setHigh() override    { state = true;  ++writes; }
    void setLow() override     { state = false; ++writes; }
    void toggle() override     { state = !state; ++writes; }
    bool read() const override { return state; }
    bool state = false;
    int writes = 0;
};
```

## 3. Dependency injection: the application gets the pin from outside

```c++
class LedController {
  public:
    explicit LedController(IGpioPin& pin) : pin_(pin) {}
    void on()  { pin_.setHigh(); }
    void off() { pin_.setLow(); }
  private:
    IGpioPin& pin_;          // depends on the abstraction only
};

// Firmware:   Stm32GpioPin pin(GPIOC, GPIO_PIN_13);   LedController led(pin);
// Linux:      LinuxGpioPin pin("gpiochip0", 13);      LedController led(pin);
// Unit test:  MockGpioPin pin; LedController led(pin); led.on(); assert(pin.state);
```

Only the *composition root* (`main()` or the board setup file) knows which implementation is used.

## 4. Static polymorphism: when you can't afford virtual calls

Virtual functions are **not** zero-cost.
Each call is an indirect call through the vtable, which the compiler usually can't inline,
and each object stores a vtable pointer.
That's negligible on Linux, but it can matter in a tight ISR loop or on a small MCU.
If the hardware is known at compile time, use templates. With C++20, a **concept** documents the interface:

```c++
#include <concepts>

template <typename T>
concept GpioPin = requires(T p, const T cp) {
    p.setHigh(); p.setLow(); p.toggle();
    { cp.read() } -> std::convertible_to<bool>;
};

template <GpioPin Pin>
class LedControllerT {
  public:
    explicit LedControllerT(Pin& pin) : pin_(pin) {}
    void on() { pin_.setHigh(); }     // resolved at compile time, can be inlined to a register write
  private:
    Pin& pin_;
};
```

The trade-off: you get one instantiation per pin type, and the platform must be fixed at build time.
Interfaces (section 3) are simpler when you need runtime choice or mocks without templates.

## 5. Benefits and limits

+ **Portability**: a new board or chip needs new implementation classes, and the application logic stays the same.
  This works only if the interface was designed around *behavior*,
  not around one chip's features (for example, don't put `setAlternateFunction(AF7)` in a generic interface).
+ **Testability**: business logic runs on a PC with mocks, without hardware.
+ **Encapsulation**: hardware details (ports, line offsets, file descriptors) are private to one class.
  This is a design discipline: C++ access control doesn't stop other code from writing to memory-mapped registers.
+ **Resource safety (RAII)**: constructors acquire, destructors release (`gpiod_line_release`, `close`).
  Forbid copying classes that own hardware.
+ **Cost**: an extra layer to maintain. Don't abstract what will never change.

## 6. Where this is used

+ **MCU firmware**: C++ wrappers around STM32Cube, ESP-IDF, or NXP MCUXpresso; frameworks like Zephyr (C, devicetree-driven) and mbed OS.
+ **Embedded Linux products**: a C++ HAL library over libgpiod, `/sys/class/leds`, IIO, and `/dev/i2c-N`.
+ **Android**: HALs are defined by **stable AIDL** interfaces and implemented as C++ (NDK backend) or Rust services,
  called over Binder from the framework. The older `libhardware` HALs were C structs of function pointers.
  See [../Android/HAL_intro.md](../Android/HAL_intro.md).

## Related notes

+ [HAL_DeviceTree.md](HAL_DeviceTree.md): device tree → kernel driver → user-space HAL (LED example)
+ [HAL_mmio_vs_sysfs.md](HAL_mmio_vs_sysfs.md): how a Linux HAL should reach hardware
+ [HAL_Std_Func.md](HAL_Std_Func.md): MCU vendor HAL functions

## Reference

+ [libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
+ [C++ Core Guidelines: interfaces (I) and classes (C)](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
