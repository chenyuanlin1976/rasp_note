# Pure C++ AIDL service (NDK backend): LED control through sysfs

With the **NDK backend** (`libbinder_ndk`), you can write **both the service and the client in C++**.
There is no JVM/ART and no JNI.
The `.aidl` file is the same one a Java client would use; only the generated code differs.

This example controls an LED through the kernel LED class (`/sys/class/leds/<name>/`).
For the design (Lights HAL vs a custom HAL, kernel blinking), see [Led_control.md](Led_control.md); for the sysfs side, [../Linux/sysfs_led_class.md](../Linux/sysfs_led_class.md).

## 1. The AIDL file

The path must match the package: `com/example/led/ILedControl.aidl`.

```java
package com.example.led;

interface ILedControl {
    const int STATE_OFF   = 0;
    const int STATE_ON    = 1;
    const int STATE_BLINK = 2;

    /** delayOn/delayOff (ms) are used only for STATE_BLINK. */
    void setLedState(int state, int delayOnMs, int delayOffMs);
}
```

## 2. Android.bp

```bp
aidl_interface {
    name: "com.example.led",            // = package name; libs become com.example.led-ndk, ...
    srcs: ["com/example/led/ILedControl.aidl"],
    unstable: true,                     // client and service are built together in one partition
    backend: {
        java: { enabled: false },
        cpp:  { enabled: false },
        ndk:  { enabled: true },
    },
}

cc_binary {
    name: "led_control_service",
    srcs: ["LedControlService.cpp", "main.cpp"],
    shared_libs: ["libbinder_ndk", "liblog", "com.example.led-ndk"],
    init_rc: ["led_control_service.rc"],
}
```

About `stability`:

+ `unstable: true` is enough if every user of the interface is built **in the same partition** (for example, all on `system`).
  That is fine for a platform-internal tool or a prototype.
+ For a **product**, LED control belongs to the vendor (the LED, its sysfs node, and its SELinux label are vendor-specific).
  So make it a vendor HAL that the framework calls, which means the interface crosses system ↔ vendor and needs `stability: "vintf"`.
  That is **not** an optional extra: it also requires `@VintfStability` on the interface, `vendor_available: true`,
  a frozen version (`m com.example.led-freeze-api`), and the `-V1-ndk` library name.
  See [AIDL_HAL_impl.md](AIDL_HAL_impl.md).

The build generates `<aidl/com/example/led/ILedControl.h>` and `<aidl/com/example/led/BnLedControl.h>`
in the namespace `aidl::com::example::led`.

## 3. The service

### LedControlService.h

```c++
#pragma once

#include <aidl/com/example/led/BnLedControl.h>
#include <string>

class LedControlService : public aidl::com::example::led::BnLedControl {
  public:
    explicit LedControlService(std::string ledDir);

    ndk::ScopedAStatus setLedState(int32_t state, int32_t delayOnMs, int32_t delayOffMs) override;

  private:
    bool writeAttr(const char* attr, const std::string& value);
    std::string mDir;            // e.g. "/sys/class/leds/sys_led_r"
    std::string mMaxBrightness;  // read from max_brightness: 1 for a GPIO LED, 255 for many PWM LEDs
};
```

### LedControlService.cpp

```c++
#define LOG_TAG "LedControlService"

#include "LedControlService.h"

#include <cerrno>
#include <fstream>
#include <log/log.h>

using ndk::ScopedAStatus;
using aidl::com::example::led::ILedControl;

LedControlService::LedControlService(std::string ledDir) : mDir(std::move(ledDir)) {
    std::ifstream f(mDir + "/max_brightness");
    if (!(f >> mMaxBrightness)) mMaxBrightness = "1";
}

bool LedControlService::writeAttr(const char* attr, const std::string& value) {
    std::ofstream f(mDir + "/" + attr);
    f << value;
    f.flush();
    if (!f) {
        ALOGE("write %s/%s=%s failed", mDir.c_str(), attr, value.c_str());
        return false;
    }
    return true;
}

ScopedAStatus LedControlService::setLedState(int32_t state, int32_t delayOnMs, int32_t delayOffMs) {
    bool ok = false;
    switch (state) {
        case ILedControl::STATE_OFF:
            ok = writeAttr("trigger", "none") && writeAttr("brightness", "0");
            break;
        case ILedControl::STATE_ON:
            ok = writeAttr("trigger", "none") && writeAttr("brightness", mMaxBrightness);
            break;
        case ILedControl::STATE_BLINK:
            // delay_on/delay_off exist only after trigger=timer, so set the trigger first
            ok = writeAttr("trigger", "timer") &&
                 writeAttr("delay_on", std::to_string(delayOnMs)) &&
                 writeAttr("delay_off", std::to_string(delayOffMs));
            break;
        default:
            return ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }
    return ok ? ScopedAStatus::ok() : ScopedAStatus::fromServiceSpecificError(EIO);
}
```

## 4. Register the service (main.cpp)

```c++
#define LOG_TAG "LedControlMain"

#include "LedControlService.h"

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(0);   // single binder thread = main thread (no locking needed)

    auto service = ndk::SharedRefBase::make<LedControlService>("/sys/class/leds/sys_led_r");
    const std::string instance = std::string(LedControlService::descriptor) + "/default";

    binder_exception_t err = AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (err != EX_NONE) {
        ALOGE("addService(%s) failed: %d", instance.c_str(), err);
        return EXIT_FAILURE;
    }

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;   // never reached
}
```

`descriptor` here is `"com.example.led.ILedControl"`, so the instance name is `com.example.led.ILedControl/default`.
That same name must appear in `service_contexts`, and the service needs SELinux rules to write the LED sysfs files
(see [SELinux_policy.md](SELinux_policy.md)).

## 5. A native C++ client

```c++
#include <aidl/com/example/led/ILedControl.h>
#include <android/binder_manager.h>

using aidl::com::example::led::ILedControl;

bool blinkLed() {
    const std::string instance = std::string(ILedControl::descriptor) + "/default";

    // waitForService blocks until registered; checkService returns null immediately if not yet up
    std::shared_ptr<ILedControl> led = ILedControl::fromBinder(
            ndk::SpAIBinder(AServiceManager_waitForService(instance.c_str())));
    if (led == nullptr) return false;

    ndk::ScopedAStatus st = led->setLedState(ILedControl::STATE_BLINK, 500, 500);   // Binder IPC, no JNI
    return st.isOk();
}
```

The client links `libbinder_ndk` and `com.example.led-ndk`.

## 6. Why pure C++ AIDL

+ **No JVM / JNI**: no `jstring`/`jint` conversion, a small memory footprint, and fast startup.
+ **Fits system daemons and HALs** that run outside the Android runtime.
+ **Stable ABI** (NDK backend): the same code works in vendor, APEX, or system modules.
  The older `cpp` backend (`libbinder`) is limited to platform-internal code; see [AIDL_backends.md](AIDL_backends.md).

## Related notes

+ [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md): the same pattern with libgpiod
+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md): turning a service like this into a stable vendor HAL
+ [Led_control.md](Led_control.md)

## Reference

+ [AIDL backends](https://source.android.com/docs/core/architecture/aidl/aidl-backends)
