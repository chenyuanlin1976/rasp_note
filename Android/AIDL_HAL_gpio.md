# GPIO vendor AIDL HAL (NDK backend) with libgpiod

An Android app **can't** open `/dev/gpiochip*` itself: the app sandbox, DAC permissions, and SELinux all block it.
Instead, a **native daemon** owns the GPIO lines and exposes them through an **AIDL** interface:

```text
App / system app --(Binder, AIDL)--> native C++ GPIO service --(libgpiod)--> /dev/gpiochipN --> SoC pins (e.g. RK3566)
```

This example is a **vendor AIDL HAL** built with the **NDK backend**.
That's the setup Android expects for hardware-access daemons on the vendor partition.
For the full generic HAL plumbing (VINTF matrix, client code), see [AIDL_HAL_impl.md](AIDL_HAL_impl.md).

| Item | Value |
| --- | --- |
| Package / `aidl_interface` | `vendor.example.hardware.gpio` |
| Interface | `IGpioControl` |
| Instance | `vendor.example.hardware.gpio.IGpioControl/default` |
| Executable | `/vendor/bin/hw/vendor.example.hardware.gpio-service` |
| libgpiod API | **v1** (`gpiod_line_*`), see [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md); v2 replaced it with `gpiod_chip_request_lines()` / `gpiod_line_request_*` |

## 1. The AIDL interface

```java
// aidl/vendor/example/hardware/gpio/IGpioControl.aidl
package vendor.example.hardware.gpio;

@VintfStability
interface IGpioControl {
    /** Drive a line as output. Errors are reported as ServiceSpecificException(errno). */
    void setLineValue(int chip, int lineOffset, boolean high);

    /** Read a line. If this service already drives it as output, returns the driven value. */
    boolean getLineValue(int chip, int lineOffset);
}
```

## 2. The service implementation

Design points:

+ **Keep output lines requested** for the life of the service.
  If you release a line right after setting it, the kernel no longer guarantees its value or direction,
  and another process may grab it.
+ **Don't re-request an output line as input** just to read it, because that flips the pin's direction.
  If the service already holds the line as an output, read it through that same handle.
  If the line is an output that the service *doesn't* own, refuse with `EPERM`.
+ Binder calls arrive on several threads, so protect the shared state with a **mutex**.
+ Report failures with `fromServiceSpecificError(errno)`, not with a `false` return value.

### GpioControl.h

```c++
#pragma once

#include <aidl/vendor/example/hardware/gpio/BnGpioControl.h>
#include <gpiod.h>

#include <map>
#include <mutex>
#include <utility>

namespace aidl::vendor::example::hardware::gpio {

class GpioControl : public BnGpioControl {
  public:
    ~GpioControl() override;

    ndk::ScopedAStatus setLineValue(int32_t chip, int32_t lineOffset, bool high) override;
    ndk::ScopedAStatus getLineValue(int32_t chip, int32_t lineOffset, bool* _aidl_return) override;

  private:
    gpiod_chip* openChipLocked(int32_t chip);

    static constexpr const char* kConsumer = "gpio-aidl-service";

    std::mutex mLock;
    std::map<int32_t, gpiod_chip*> mChips;                       // chip number -> open chip
    std::map<std::pair<int32_t, int32_t>, gpiod_line*> mOutputs; // (chip, offset) -> held output line
};

}  // namespace aidl::vendor::example::hardware::gpio
```

### GpioControl.cpp

```c++
#define LOG_TAG "GpioControl"

#include "GpioControl.h"

#include <cerrno>
#include <string>
#include <log/log.h>

namespace aidl::vendor::example::hardware::gpio {

using ndk::ScopedAStatus;

static ScopedAStatus errnoStatus(const char* what) {
    int err = errno ? errno : EIO;
    ALOGE("%s failed: %d", what, err);
    return ScopedAStatus::fromServiceSpecificError(err);
}

GpioControl::~GpioControl() {
    for (auto& [key, line] : mOutputs) gpiod_line_release(line);
    for (auto& [num, chip] : mChips) gpiod_chip_close(chip);
}

gpiod_chip* GpioControl::openChipLocked(int32_t chip) {
    auto it = mChips.find(chip);
    if (it != mChips.end()) return it->second;

    std::string path = "/dev/gpiochip" + std::to_string(chip);
    gpiod_chip* c = gpiod_chip_open(path.c_str());
    if (c != nullptr) mChips.emplace(chip, c);
    return c;
}

ScopedAStatus GpioControl::setLineValue(int32_t chip, int32_t lineOffset, bool high) {
    std::lock_guard<std::mutex> guard(mLock);
    const int value = high ? 1 : 0;

    // Already ours as output: just change the value
    auto it = mOutputs.find({chip, lineOffset});
    if (it != mOutputs.end()) {
        if (gpiod_line_set_value(it->second, value) < 0) return errnoStatus("gpiod_line_set_value");
        return ScopedAStatus::ok();
    }

    gpiod_chip* c = openChipLocked(chip);
    if (c == nullptr) return errnoStatus("gpiod_chip_open");

    gpiod_line* line = gpiod_chip_get_line(c, lineOffset);
    if (line == nullptr) return errnoStatus("gpiod_chip_get_line");

    // Request as output WITH the initial value -> no glitch; EBUSY if a kernel driver owns it
    if (gpiod_line_request_output(line, kConsumer, value) < 0) {
        return errnoStatus("gpiod_line_request_output");
    }
    mOutputs.emplace(std::make_pair(chip, lineOffset), line);   // keep it requested
    return ScopedAStatus::ok();
}

ScopedAStatus GpioControl::getLineValue(int32_t chip, int32_t lineOffset, bool* _aidl_return) {
    std::lock_guard<std::mutex> guard(mLock);

    // Driven by us: read back through the existing handle (does NOT change direction)
    auto it = mOutputs.find({chip, lineOffset});
    if (it != mOutputs.end()) {
        int v = gpiod_line_get_value(it->second);
        if (v < 0) return errnoStatus("gpiod_line_get_value");
        *_aidl_return = (v == 1);
        return ScopedAStatus::ok();
    }

    // Not ours: request as input briefly, read, release
    gpiod_chip* c = openChipLocked(chip);
    if (c == nullptr) return errnoStatus("gpiod_chip_open");

    gpiod_line* line = gpiod_chip_get_line(c, lineOffset);
    if (line == nullptr) return errnoStatus("gpiod_chip_get_line");

    // Requesting an input would switch an output pin (set up by the bootloader or by another
    // owner) to input. Refuse instead of silently changing the hardware state.
    if (gpiod_line_direction(line) == GPIOD_LINE_DIRECTION_OUTPUT) {
        return ScopedAStatus::fromServiceSpecificError(EPERM);
    }

    if (gpiod_line_request_input(line, kConsumer) < 0) return errnoStatus("gpiod_line_request_input");
    int v = gpiod_line_get_value(line);
    gpiod_line_release(line);
    if (v < 0) return errnoStatus("gpiod_line_get_value");

    *_aidl_return = (v == 1);
    return ScopedAStatus::ok();
}

}  // namespace aidl::vendor::example::hardware::gpio
```

## 3. Register the service (main.cpp)

```c++
#define LOG_TAG "GpioControlMain"

#include "GpioControl.h"

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

using aidl::vendor::example::hardware::gpio::GpioControl;

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(4);   // calls may run concurrently -> class uses a mutex
    ABinderProcess_startThreadPool();

    std::shared_ptr<GpioControl> service = ndk::SharedRefBase::make<GpioControl>();
    const std::string instance = std::string(GpioControl::descriptor) + "/default";

    if (AServiceManager_addService(service->asBinder().get(), instance.c_str()) != EX_NONE) {
        ALOGE("Failed to register %s", instance.c_str());
        return EXIT_FAILURE;
    }

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;   // never reached
}
```

## 4. Android.bp

```bp
// aidl/Android.bp
aidl_interface {
    name: "vendor.example.hardware.gpio",
    vendor_available: true,
    srcs: ["vendor/example/hardware/gpio/IGpioControl.aidl"],
    stability: "vintf",
    backend: {
        cpp:  { enabled: false },
        java: { enabled: true, sdk_version: "module_current" },   // for the system app / framework client
        ndk:  { enabled: true },
    },
    versions_with_info: [{ version: "1", imports: [] }],          // after "m vendor.example.hardware.gpio-freeze-api"
    frozen: true,
}

// default/Android.bp
cc_binary {
    name: "vendor.example.hardware.gpio-service",
    vendor: true,
    relative_install_path: "hw",
    init_rc: ["vendor.example.hardware.gpio-service.rc"],
    vintf_fragments: ["vendor.example.hardware.gpio-service.xml"],
    srcs: ["GpioControl.cpp", "main.cpp"],
    shared_libs: [
        "libbinder_ndk",
        "liblog",
        "libgpiod",                              // see note below
        "vendor.example.hardware.gpio-V1-ndk",
    ],
    cflags: ["-Wall", "-Werror"],
}
```

Notes:

+ **libgpiod is not part of AOSP.** It's a user-space library, not a kernel feature.
  You have to add its source (for example under `external/libgpiod` or `vendor/<you>/libgpiod`) with an `Android.bp`
  that builds `libgpiod` with `vendor_available: true` or `vendor: true`.
  The kernel only has to provide the GPIO character device (`CONFIG_GPIO_CDEV`, plus `CONFIG_GPIO_CDEV_V1` for the v1 API).
+ **Why NDK + `vintf`, not `unstable: true` / the cpp backend?**
  + An `unstable` interface can't be used across the system ↔ vendor boundary.
    The system app client would be on `system`, while the daemon is on `vendor`.
  + The cpp backend (`libbinder`) on the vendor partition registers with **`vndservicemanager`** (`/dev/vndbinder`),
    so framework and system apps can't see the service. (`/dev/vndbinder` is also deprecated since Android 11.)

## 5. init, ueventd, VINTF

```text
# vendor.example.hardware.gpio-service.rc
service vendor.example.hardware.gpio-service /vendor/bin/hw/vendor.example.hardware.gpio-service
    class hal
    user system
    group system
```

```text
# vendor ueventd.rc: let the daemon (non-root) open the chips
/dev/gpiochip*    0660   system   system
```

```xml
<!-- vendor.example.hardware.gpio-service.xml -->
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>vendor.example.hardware.gpio</name>
        <version>1</version>
        <fqname>IGpioControl/default</fqname>
    </hal>
</manifest>
```

Also add the HAL to the device framework compatibility matrix (see [AIDL_HAL_impl.md](AIDL_HAL_impl.md#3-init-script-and-vintf)).
Avoid `user root`: the service needs only access to the device nodes, which the `ueventd.rc` line grants.

## 6. SELinux

The client is a **system-side** app (see [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)).
So the HAL attribute and the service type go in **`system_ext/public`**, where both partitions' policies can see them.
The reason is explained in [AIDL_HAL_impl.md](AIDL_HAL_impl.md#4-selinux).

```text
# device/<vendor>/<board>/sepolicy/system_ext/public/hal_gpioctl.te
hal_attribute(gpioctl)
type hal_gpioctl_service, hal_service_type, protected_service, service_manager_type;
hal_attribute_service(hal_gpioctl, hal_gpioctl_service)

# device/<vendor>/<board>/sepolicy/vendor/hal_gpioctl_default.te
type hal_gpioctl_default, domain;
hal_server_domain(hal_gpioctl_default, hal_gpioctl)
type hal_gpioctl_default_exec, exec_type, vendor_file_type, file_type;
init_daemon_domain(hal_gpioctl_default)          # domain transition instead of "seclabel" in .rc

type gpio_device, dev_type;
allow hal_gpioctl_default gpio_device:chr_file rw_file_perms;   # rw_file_perms includes ioctl

# vendor/file_contexts
/dev/gpiochip[0-9]+                                         u:object_r:gpio_device:s0
/vendor/bin/hw/vendor\.example\.hardware\.gpio-service      u:object_r:hal_gpioctl_default_exec:s0

# vendor/service_contexts
vendor.example.hardware.gpio.IGpioControl/default           u:object_r:hal_gpioctl_service:s0
```

The client's domain (the system app in [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md)) gets `hal_client_domain(<client_domain>, hal_gpioctl)`
in `system_ext/private`.

## 7. Calling it

Native C++ client (NDK):

```c++
auto name = std::string(IGpioControl::descriptor) + "/default";
auto gpio = IGpioControl::fromBinder(ndk::SpAIBinder(AServiceManager_waitForService(name.c_str())));
if (gpio) {
    ndk::ScopedAStatus st = gpio->setLineValue(4, 29, true);   // RK3566 GPIO4_D5 = 3*8+5 = 29
    if (!st.isOk()) ALOGE("set failed: %s", st.getDescription().c_str());
}
```

Kotlin, in a **platform-signed system app** (it uses the hidden `ServiceManager` API and `...-V1-java`):

```kotlin
val binder = ServiceManager.waitForDeclaredService("${IGpioControl.DESCRIPTOR}/default")
val gpio = IGpioControl.Stub.asInterface(binder)
try {
    gpio?.setLineValue(4, 29, true)            // GPIO4_D5 on
} catch (e: ServiceSpecificException) {
    Log.e(TAG, "GPIO error errno=${e.errorCode}")   // e.g. 16 = EBUSY (line owned by a kernel driver)
}
```

Third-party apps go through that system app; see [AIDL_app_3rdParty_access.md](AIDL_app_3rdParty_access.md).

## 8. RK3566 notes

+ Pin numbering: `GPIO<bank>_<group><n>` → chip = bank, offset = group × 8 + n (A=0, B=1, C=2, D=3).
  For example, GPIO4_D5 → `gpiochip4`, line 29.
  Confirm the chip-to-bank mapping with `gpiodetect` / `gpioinfo`.
+ If a line is claimed by a kernel driver (device tree `*-gpios`), `gpiod_line_request_output` fails with `EBUSY`.
  See [AIDL_HAL_intro.md](AIDL_HAL_intro.md#5-describing-the-gpio-in-the-device-tree-dtsi).
+ The pin must be muxed as GPIO (pinctrl) in the device tree.

## Related notes

+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [AIDL_ndk_led_sysfs.md](AIDL_ndk_led_sysfs.md)
+ [../Linux/libgpiod_intro.md](../Linux/libgpiod_intro.md), [libgpiod_android.md](libgpiod_android.md), [HAL_libgpiod.md](HAL_libgpiod.md), [gpio_control.md](gpio_control.md)

## Reference

+ [libgpiod](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
