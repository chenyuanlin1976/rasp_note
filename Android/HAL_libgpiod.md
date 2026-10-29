# HAL and libgpiod

In the Android ecosystem, interacting with GPIO (General Purpose Input/Output) pins  
involves bridging **user-space** application demands down to the **Linux kernel** via the Hardware Abstraction Layer (HAL).

When developers refer to `libgpiod` or implementing a GPIO HAL in Android, they are generally addressing  
how user-space processes (like Android apps or system services) can safely control hardware pins  
(for LEDs, buttons, sensors, etc.) without directly exposing kernel raw drivers.

## 1. The Android GPIO Architecture Flow

To control a GPIO pin from an Android app, the request flows through multiple layers:

**Android App (Java/Kotlin) --> JNI --> Android Framework Service --> HAL (libgpiod/Vendor Library) -->Linux Kernel (sysfs/ char cdev)**

## 2. How GPIO is Handled in Linux & Android HAL

Depending on the Android version and Linux kernel configuration,  
implementing a GPIO HAL generally takes one of 2 approaches:

### Approach A: The Legacy sysfs Interface (/sys/class/gpio)

Historically, user-space libraries interacted with Linux GPIOs via text files in `/sys/class/gpio/`.

+ How it works in the HAL: Your `libgpiod` wrapper  
  or HAL implementation **writes strings to files** like `/sys/class/gpio/export`, direction, and value.
+ Drawback: Deprecated in modern Linux kernels due to performance overhead and race conditions.

## Approach B: The Modern Character Device Interface (/dev/gpiochipN)

Modern kernels use `libgpiod` (or direct ioctl calls to `/dev/gpiochipN`).

+ How it works in the HAL: A custom vendor HAL library links against  
  or implements standard character device file operations  
  to configure lines, read inputs, and write outputs securely.

## 3. Implementing a Custom GPIO HAL

If you are building a custom Android build (AOSP) for an embedded board  
(like an NXP, Qualcomm, or Rockchip platform)  
and need a custom libgpio HAL, you typically follow these steps:

### Step 1: Define the HIDL / AIDL Interface (Android 8+)

In modern Android, hardware components are exposed via AIDL (Android Interface Definition Language).  
You define an interface for your GPIO service:

```java
package vendor.example.gpio;

interface IGpio {
    boolean setDirection(int pin, boolean output);
    boolean write(int pin, boolean value);
    boolean read(int pin);
}
```

### Step 2: Implement the HAL Library (libgpio_hal)

Your C/C++ native implementation (`libgpiod`) talks to the underlying Linux device nodes:

```c++
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>

// Example pseudo-code for writing to a legacy sysfs GPIO node in the HAL
bool gpio_set_value(int pin, int value) {
    char path[64];
    char val_str[2];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", pin);
    
    int fd = open(path, O_WRONLY);
    if (fd < 0) return false;
    
    snprintf(val_str, sizeof(val_str), "%d", value);
    write(fd, val_str, strlen(val_str));
    close(fd);
    return true;
}
```

### Step 3: Expose via a System Service & SELinux Policies

1. SELinux Permissions: Because Android enforces strict sandboxing,  
   your HAL context (`hal_gpio_default.te`) must be granted permissions to access `/dev/gpiochip*` or `/sys/class/gpio/*`.
2. Init Scripts (`.rc`): Create an init rc script to adjust file descriptors or ownership permissions on boot if necessary.

## Alternative: Android Things (Historical Context)

If you encountered `libgpiod` or peripheral APIs in older documentation,  
you might be thinking of Android Things (Google's discontinued IoT OS variant),  
which provided a built-in PeripheralManagerService allowing direct Java API calls to GPIOs.  

For standard AOSP today, developers implement custom vendor HALs  
or use bound background services interacting directly with native Daemons.
