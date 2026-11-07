# Native (C/C++) code via JNI: hardware access, privileges, performance

A common plan to control hardware (GPIO, LEDs, a sensor) from an Android app goes like this:
"Kotlin can't open `/sys/class/gpio`, so I'll do it in C through JNI."
That plan **doesn't work**. This note explains why, what does work, and what C really gains over Kotlin.
For JNI basics, see [JNI_intro.md](JNI_intro.md) and [JNI_android_studio.md](JNI_android_studio.md).

## 1. Native code has no extra privileges

The OS grants privileges to **processes**, not to languages.
A JNI library is loaded **into the app's process**, so it runs with exactly the same:

+ **UID / GIDs** (e.g. `u0_a123`), which decide DAC file permissions
+ **SELinux domain** (e.g. `untrusted_app`), which decides MAC permissions
+ capabilities, seccomp filter, and mount namespace

If Kotlin's `File("/sys/class/gpio/export").writeText("17")` fails with `EACCES`,
C's `open("/sys/class/gpio/export", O_WRONLY)` fails in the same way.
The kernel can't tell the two apart.

Android doesn't rely on the VM for security: the **VM is not a security boundary**.
So native code doesn't "escape" anything by leaving ART. The sandbox is the process (UID + SELinux).
That does make native memory bugs more dangerous, though:
a buffer overflow in a `.so` can be exploited with **all** of the app's permissions.

## 2. What actually grants hardware access

| Approach | Does it work? | Notes |
| --- | --- | --- |
| Normal app + JNI | **No** | DAC and SELinux block `/sys`, `/dev`, and `/dev/mem` for `untrusted_app` |
| App calls `su -c ...` (rooted dev board) | Only on rooted/debug builds | `su` starts a **separate** root process. The app process and its JNI code stay unprivileged. `su` doesn't exist on user builds |
| Platform-signed / system app | Mostly **no** for raw device nodes | It gets signature permissions and a `platform_app`/`system_app` domain, but SELinux `neverallow` rules still forbid app domains from most sysfs/device access. Being in `/system/app` alone gives nothing |
| Change ownership in `init.rc` / `ueventd.rc` | Only together with SELinux rules | App UIDs are assigned at install time, so you can't hard-code them. This fixes DAC only, not SELinux |
| **Privileged native service / HAL**, called over Binder | **Yes: the production design** | Its own domain and UID, with specifically labeled nodes. The app talks to it through AIDL |

The correct architecture is:

```text
App (Kotlin) --Binder/AIDL--> system app (bound service) --Binder/stable AIDL--> GPIO HAL (C++, own SELinux domain) --libgpiod--> /dev/gpiochipN
```

It's described in [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md) and [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md),
and why the shortcuts fail at build time is in [neverallow_error.md](neverallow_error.md).

## 3. Example: a GPIO write in JNI code (rooted dev board / lab only)

This is useful for bring-up on a dev board where you control SELinux and permissions,
for example with `setenforce 0` on a userdebug build and the node `chmod`-ed.
It uses the **legacy sysfs** interface; the character device with libgpiod is preferred (see [HAL_libgpiod.md](HAL_libgpiod.md)).

```c
/* gpio_control.c */
#include <jni.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* Returns 0 on success, or -errno (e.g. -13 = EACCES) so Kotlin can see WHY it failed */
JNIEXPORT jint JNICALL
Java_com_example_gpioapp_GpioNative_setGpio(JNIEnv *env, jclass clazz, jint gpio, jboolean high) {
    char path[64];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", (int) gpio);  /* GLOBAL gpio number; must be exported */

    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return -errno;

    ssize_t n = write(fd, high ? "1" : "0", 1);
    int err = (n == 1) ? 0 : -errno;
    close(fd);
    return err;
}
```

```kotlin
package com.example.gpioapp

object GpioNative {
    init { System.loadLibrary("gpio_control") }
    @JvmStatic external fun setGpio(gpio: Int, high: Boolean): Int
}

// usage: val rc = GpioNative.setGpio(17, true)   // rc == -13 -> EACCES: blocked by DAC/SELinux
```

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("gpioapp" C)
add_library(gpio_control SHARED gpio_control.c)
```

The Gradle `externalNativeBuild` setup is in [JNI_android_studio.md](JNI_android_studio.md#1-project-setup).

## 4. C vs Kotlin when access is allowed

Suppose the process is allowed to open the node, for example inside a privileged service.
How much does the language matter then?

| | Kotlin (ART) | C/C++ (NDK) |
| --- | --- | --- |
| Writing a sysfs / device file | Fine: `FileOutputStream`, or `Os.open`/`Os.write`; you can keep the descriptor open | Fine: `open`/`write`/`ioctl` |
| Cost per GPIO write | Dominated by the **system call** and the driver (µs); the language adds little | Same system call |
| `ioctl` (e.g. GPIO chardev, I2C, SPI) | Not available in the public SDK API | **Native code is required** |
| `mmap` of hardware registers | Not practical | Possible, but needs `/dev/mem` (root, and `CONFIG_STRICT_DEVMEM` usually blocks it), so it's **not** an option on production Android |
| Bit operations | Same machine instructions (`and`, `or`, `shl`, `ushr`) | Same |
| GC pauses | ART's GC is concurrent, but short pauses still happen | Threads that aren't attached to ART aren't paused by the GC |
| Timing determinism | **No** | **No**: Android is not a real-time OS. Scheduling, interrupts, and CPU frequency changes add jitter of 10s of µs to ms |
| Reusing vendor C SDKs / libgpiod | Needs a JNI or AIDL wrapper | Direct |

Conclusions:

+ An occasional on/off (a relay, an LED, a button in the UI) runs at the same speed in Kotlin or C.
  Choose based on where the code lives (the HAL is usually C++) and which libraries you need (libgpiod is C).
+ Native code is needed for `ioctl`-based interfaces and for reusing C libraries, **not** for speed or for privileges.
+ For **µs-precise timing** (bit-banging a protocol, software PWM), neither works from Android user space.
  Use hardware peripherals (PWM, SPI, UART, I2C controllers) or a co-processor MCU
  (see [HAL_STM32_example.md](HAL_STM32_example.md)).

## Related notes

+ [JNI_intro.md](JNI_intro.md), [JNI_android_studio.md](JNI_android_studio.md)
+ [HAL_libgpiod.md](HAL_libgpiod.md#2-do-i-need-jni-native-aidl-hal-vs-jni): JNI vs a native AIDL HAL for libgpiod
+ [HAL_libgpiod.md](HAL_libgpiod.md), [hw_control_sysfs.md](hw_control_sysfs.md), [SELinux_intro.md](SELinux_intro.md)

## Reference

+ [Application sandbox (AOSP)](https://source.android.com/docs/security/app-sandbox)
+ [JNI tips](https://developer.android.com/training/articles/perf-jni)
