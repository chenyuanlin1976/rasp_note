# GPIO HAL and libgpiod

This note covers how an AOSP device (for example RK3566) lets user space control **GPIO pins** safely:

+ which kernel interface to use
+ what libgpiod is
+ where it fits in an Android HAL

The complete, buildable AIDL GPIO HAL is in [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md).

## 1. Architecture

```text
App (Java/Kotlin)
   |  Binder: bindService() to a system app, or a framework API
   v
System app / framework service           (system partition)
   |  Binder: stable AIDL HAL interface
   v
GPIO HAL service (C++/Rust)              (vendor partition, /vendor/bin/hw/...)
   |  libgpiod -> ioctl()
   v
/dev/gpiochipN  (GPIO character device)  (kernel gpiolib)
   v
SoC GPIO controller -> pin
```

+ Each arrow between processes is **Binder IPC**. You don't need JNI in this path:
  AIDL generates the Java proxy and the C++ stub.
  JNI is needed only if a Java class must call a native library **in its own process**
  (see [libgpiod_HAL.md](libgpiod_HAL.md)).
+ Third-party apps can't call a vendor HAL directly. They go through a system app;
  see [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md).

## 2. The 2 kernel interfaces for GPIO

| | sysfs GPIO (`/sys/class/gpio`) | GPIO character device (`/dev/gpiochipN`) |
| --- | --- | --- |
| Status | **Deprecated** since Linux 4.8 (`CONFIG_GPIO_SYSFS`); often disabled in GKI/Android kernels | Current interface: uAPI v1 since 4.8, **v2 since 5.10** |
| Addressing | Global GPIO **number** (chip base + offset); the base can change between kernels | **Chip + line offset**, or a line **name** from `gpio-line-names` |
| Ownership | After `export`, the line stays exported when the process dies; no owner is recorded | The line belongs to the open file descriptor; it's **released automatically** when the process exits; a consumer label is shown |
| Multiple lines | One file write per line | Several lines set/read **atomically** in one request |
| Events | `poll()` on `value`; edges can be missed | Edge events queued, **with timestamps** |
| User-space API | Plain file I/O | `ioctl()`, normally through **libgpiod** |

**libgpiod** is a **user-space** C library (with C++ and Python bindings) and tools
(`gpiodetect`, `gpioinfo`, `gpioget`, `gpioset`, `gpiomon`) for the **character device only**.
It **never uses sysfs**.
It is also **not** a kernel feature: the kernel provides `/dev/gpiochipN`, and libgpiod wraps its ioctls.

libgpiod has 2 incompatible API generations:

+ **v1.x**: `gpiod_chip_get_line()`, `gpiod_line_request_output()`, `gpiod_line_set_value()`.
  The other notes here use this one ([libgpiod_intro2.md](libgpiod_intro2.md)).
+ **v2.x** (2022+): `gpiod_line_settings`, `gpiod_line_config`, `gpiod_chip_request_lines()`, `gpiod_line_request_set_value()`.

## 3. The same "set a pin high" in both interfaces

### 3.1 sysfs (legacy; only if the kernel still has `CONFIG_GPIO_SYSFS`)

```c++
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>

static bool writeFile(const char* path, const char* text) {
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return false;
    ssize_t n = write(fd, text, strlen(text));
    close(fd);
    return n == static_cast<ssize_t>(strlen(text));
}

// gpio = GLOBAL number. On RK3566 with the classic base = bank * 32: GPIO4_D5 -> 4*32 + 29 = 157.
// Newer kernels allocate bases dynamically (e.g. from 512): check /sys/class/gpio/gpiochip*/base.
bool sysfsGpioSet(int gpio, bool high) {
    char path[64], num[16];
    snprintf(num, sizeof(num), "%d", gpio);
    writeFile("/sys/class/gpio/export", num);          // fails with EBUSY if already exported: OK

    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio);
    // "high"/"low" sets output AND the initial level in one write (no glitch)
    return writeFile(path, high ? "high" : "low");
}
```

### 3.2 Character device with libgpiod (v1 API)

```c++
#include <gpiod.h>

// chip = bank number, offset = line within the chip: GPIO4_D5 -> gpiochip4, line 29
gpiod_line* requestOutput(int chip, unsigned offset, bool high) {
    gpiod_chip* c = gpiod_chip_open_by_number(chip);              // opens /dev/gpiochip<chip>
    if (!c) return nullptr;
    gpiod_line* line = gpiod_chip_get_line(c, offset);
    if (!line || gpiod_line_request_output(line, "gpio-hal", high ? 1 : 0) < 0) {
        gpiod_chip_close(c);                                      // e.g. EBUSY: a kernel driver owns it
        return nullptr;
    }
    return line;   // keep it: the line (and its level) stays ours until released / process exit
}
// later:   gpiod_line_set_value(line, 0);
// cleanup: gpiod_chip* c = gpiod_line_get_chip(line); gpiod_line_release(line); gpiod_chip_close(c);
```

A line that's requested and then immediately released no longer has a guaranteed state.
A long-running HAL should keep its output lines requested.

## 4. Building a GPIO HAL in AOSP: checklist

Every item is shown in full in [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md).

1. **Interface**: a stable AIDL interface (`@VintfStability`, `stability: "vintf"`), for example `vendor.example.hardware.gpio.IGpioControl`.
   Report errors with `ServiceSpecificException` / `ScopedAStatus::fromServiceSpecificError()`, not with `boolean` return codes.
   (HIDL was used for Android 8–10 HALs; new HALs are AIDL, available since Android 11.)
2. **libgpiod in the tree**: AOSP does **not** include libgpiod.
   Add it (for example under `external/libgpiod` or `vendor/<you>/libgpiod`) with an `Android.bp` that builds it for the vendor partition.
   The kernel needs `CONFIG_GPIO_CDEV` (and `CONFIG_GPIO_CDEV_V1` for the libgpiod v1 API).
3. **Service**: an NDK-backend C++ daemon in `/vendor/bin/hw/`, started by an `.rc` file with `class hal`, and declared in the VINTF manifest.
4. **Device-node permissions**: `ueventd.rc`, for example `/dev/gpiochip*  0660  system  system`, so the HAL doesn't need root.
5. **SELinux**:
   + label `/dev/gpiochip[0-9]+` with a custom type in `file_contexts`
   + allow the HAL's domain `rw_file_perms` on it
   + add `service_contexts` + `hal_attribute_service`
   + give each client `hal_client_domain`
6. **Device tree**: the pin must be muxed as GPIO and **not claimed by a kernel driver**, or the request fails with `EBUSY`.
   Use `gpio-line-names` so the HAL can find the line by name.
   See [AIDL_HAL.md](AIDL_HAL.md#5-describing-the-gpio-in-the-device-tree-dtsi).

Debugging on the device:

```shell
gpiodetect                  # list chips (needs the libgpiod tools on the device)
gpioinfo gpiochip4          # line names, direction, and consumer ("used by")
adb logcat | grep avc       # SELinux denials
ls -lZ /dev/gpiochip*       # owner, mode, and SELinux label
```

## 5. Historical note: Android Things

Android Things, Google's IoT variant of Android (discontinued in 2022), had a Java **Peripheral I/O API** (`PeripheralManager`) for GPIO, I2C, SPI, and UART.
Standard AOSP has **no** public GPIO API. You build your own vendor HAL plus a system service or app, as above.

## Related notes

+ [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md): full AIDL + libgpiod GPIO HAL
+ [libgpiod_intro.md](libgpiod_intro.md), [libgpiod_intro2.md](libgpiod_intro2.md), [libgpiod_HAL.md](libgpiod_HAL.md)
+ [hw_control_sysfs.md](hw_control_sysfs.md), [gpio_control.md](gpio_control.md), [gpio_export.md](gpio_export.md)
+ [HAL_intro.md](HAL_intro.md), [HAL_sysfsNodes.md](HAL_sysfsNodes.md)

## Reference

+ [GPIO character device uAPI (kernel docs)](https://docs.kernel.org/userspace-api/gpio/chardev.html)
+ [Sysfs GPIO interface, obsolete (kernel docs)](https://docs.kernel.org/userspace-api/gpio/sysfs.html)
+ [libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
