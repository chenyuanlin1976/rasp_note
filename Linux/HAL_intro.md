# HAL in C++

A Hardware Abstraction Layer (HAL) in C++ is a software intermediate layer  
that ** low-level hardware details (like microcontrollers, registers, memory maps, or peripherals) from high-level application logic.

While traditional HALs are often written in C (using function pointer structs and #define macros),  
a C++ Native HAL leverages modern object-oriented programming (OOP) paradigms  
- such as abstract interfaces, polymorphism, inheritance, and templates—to achieve clean, reusable, and type-safe hardware abstraction.

## Core Concepts of a C++ Native HAL

### 1. Abstract Interfaces (Pure Virtual Classes):  

Instead of relying on global functions or raw hardware addresses,  
a C++ HAL defines hardware behaviors through pure virtual classes (interfaces).  
This defines what a peripheral does, not how a specific chip does it.

```c++
// Abstract Interface for a Digital Output Pin (GPIO)
class IGpioPin {
public:
    virtual ~IGpioPin() = default;
    
    virtual void setHigh() = 0;
    virtual void setLow() = 0;
    virtual void toggle() = 0;
    virtual bool getState() const = 0;
};
```

### 2. Platform-Specific Implementation (Inheritance)

Vendors or developers create concrete subclasses that inherit the interface  
and implement the target hardware's specific register manipulations (e.g., for STM32, NXP, ESP32, or Linux sysfs).

```c++
class Stm32GpioPin : public IGpioPin {
private:
    GPIO_TypeDef* port_;
    uint16_t pin_;

public:
    Stm32GpioPin(GPIO_TypeDef* port, uint16_t pin) : port_(port), pin_(pin) {}

    void setHigh() override {
        HAL_GPIO_WritePin(port_, pin_, GPIO_PIN_SET); // Vendor-specific call
    }
    
    void setLow() override {
        HAL_GPIO_WritePin(port_, pin_, GPIO_PIN_RESET);
    }

    void toggle() override {
        HAL_GPIO_TogglePin(port_, pin_, pin_);
    }

    bool getState() const override {
        return HAL_GPIO_ReadPin(port_, pin_) == GPIO_PIN_SET;
    }
};
```

### 3. Dependency Injection

High-level application modules or drivers do not initialize or know about physical pins directly.  
Instead, they accept an IGpioPin reference or pointer via dependency injection (usually through constructors).

```c++
class LedController {
private:
    IGpioPin& pin_; // Depends on abstraction, not hardware

public:
    explicit LedController(IGpioPin& pin) : pin_(pin) {}

    void flash() {
        pin_.setHigh();
        // delay...
        pin_.setLow();
    }
};
```

## Key Benefits of a C++ Native HAL

+ Portability: Moving your firmware from one microcontroller family to another  
  *only requires writing new derived classes implementing your base interfaces;*  
  your application logic remains entirely untouched.
+ Testability: You can easily pass mock or virtual implementations of hardware interfaces (e.g., a MockGpioPin) into your classes,  
  enabling robust unit testing on a host PC instead of physical hardware.
+ Encapsulation & Safety: C++ access specifiers (private, protected, public)  
  prevent application code from accidentally altering low-level control registers.
+ Zero-Cost Abstractions: When designed properly using inline functions,  
  virtual tables (vtables) optimized for specific targets, or template metaprogramming,  
  a C++ HAL introduces minimal-to-no performance overhead compared to raw C code.

## Where is it Used?

+ Embedded Systems & Microcontrollers: Modern IoT firmware frameworks and bare-metal/RTOS projects  
  (such as custom C++ wrappers around vendor SDKs like STM32Cube or ESP-IDF).
+ Operating System Architecture: Systems like Android use C++ native HAL structures  
  (via **HIDL/AIDL** interfaces in modern versions)  
  to separate hardware-specific binder services from Android's core native framework.
