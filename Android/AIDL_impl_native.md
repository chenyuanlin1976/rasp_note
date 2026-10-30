# the Native C++ AIDL Service

Implementing a Native C++ AIDL Service allows you to talk to `libgpiod` in pure C/C++  
while making your hardware functions safely callable across process boundaries  
(like from system apps or other daemons) via Android’s Binder driver.

## Step-by-Step Implementation Guide

### Step 1: Define the AIDL Interface

Create an interface file named `IGpioService.aidl`. This file defines what functions clients can call.

```java
package com.example.gpio;

interface IGpioService {
    // Set a specific GPIO line value (0 or 1)
    boolean setPinValue(int lineOffset, int value);
    
    // Get the value of a specific GPIO line
    int getPinValue(int lineOffset);
}
```

### Step 2: Write the Android.bp Build File

In your service directory, create an **Android.bp** to tell the AOSP build system  
to generate the C++ binder headers (`aidl_interface`) and compile your **native daemon binary**.

```ini
aidl_interface {
    name: "com.example.gpio",
    unstable: true,
    srcs: ["com/example/gpio/IGpioService.aidl"],
    backend: {
        cpp: {
            enabled: true,
        },
        ndk: {
            enabled: true,
        },
    },
}

cc_binary {
    name: "gpiod_service",
    srcs: [
        "GpioService.cpp",
        "main.cpp",
    ],
    shared_libs: [
        "libbase",
        "libbinder",
        "libutils",
        "libgpiod", // Link against libgpiod for GPIO operations
        "com.example.gpio-cpp", // Generated C++ AIDL bindings
    ],
    init_rc: ["gpiod_service.rc"], // For init process daemon startup
}
```

## Step 3: Implement the C++ Server Stub

Create `GpioService.h` and `GpioService.cpp` to inherit from the generated **Bn (Binder Native**) class and hook up `libgpiod`.

### GpioService.h

```c++
#pragma once

#include <binder/Status.h>
#include <com/example/gpio/BnGpioService.h>
#include <gpiod.h>

namespace com { namespace example { namespace gpio {

class GpioService : public BnGpioService {
public:
    GpioService();
    virtual ~GpioService();

    ::android::binder::Status setPinValue(int32_t lineOffset, bool value, bool* _aidl_return) override;
    ::android::binder::Status getPinValue(int32_t lineOffset, int32_t* _aidl_return) override;

private:
    struct gpiod_chip *m_chip;
    // Helper to open chip, configure lines, etc.
};

} } }
```

### GpioService.cpp

```c++
#include "GpioService.h"
#include <log/log.h>

namespace com { namespace example { namespace gpio {

GpioService::GpioService() {
    // Initialize libgpiod chip (e.g., gpiochip0)
    m_chip = gpiod_chip_open("/dev/gpiochip0");
    if (!m_chip) {
        ALOGE("Failed to open gpiochip0");
    }
}

GpioService::~GpioService() {
    if (m_chip) {
        gpiod_chip_close(m_chip);
    }
}

::android::binder::Status GpioService::setPinValue(int32_t lineOffset, bool value, bool* _aidl_return) {
    if (!m_chip) {
        *_aidl_return = false;
        return ::android::binder::Status::fromServiceSpecificError(-1);
    }

    struct gpiod_line *line = gpiod_chip_get_line(m_chip, lineOffset);
    if (!line) {
        *_aidl_return = false;
        return ::android::binder::Status::fromServiceSpecificError(-2);
    }

    // Request line as output and set value using libgpiod
    if (gpiod_line_request_output(line, "gpiod_service", 0) < 0) {
        *_aidl_return = false;
        return ::android::binder::Status::fromServiceSpecificError(-3);
    }

    int ret = gpiod_line_set_value(line, value ? 1 : 0);
    gpiod_line_release(line);

    *_aidl_return = (ret == 0);
    return ::android::binder::Status::ok();
}

::android::binder::Status GpioService::getPinValue(int32_t lineOffset, int32_t* _aidl_return) {
    // Implement read using libgpiod gpiod_line_request_input / gpiod_line_get_value
    *_aidl_return = 0;
    return ::android::binder::Status::ok();
}

} } }
```

## Step 4: Write the Service Main Entry (main.cpp)

Register your native service with Android's Service Manager so clients can discover it.

```c++
#include <binder/IPCThreadState.h>
#include <binder/ProcessState.h>
#include <binder/IServiceManager.h>
#include <utils/Log.h>
#include "GpioService.h"

using namespace com::example::gpio;

int main() {
    ALOGI("Starting GpioService...");
    
    // Setup binder process state
    android::sp<android::ProcessState> ps(android::ProcessState::self());
    ps->startThreadPool();

    // Instantiate service
    android::sp<GpioService> service = new GpioService();

    // Register with ServiceManager under name "gpio_service"
    android::defaultServiceManager()->addService(
        android::String16("gpio_service"), service
    );

    android::IPCThreadState::self()->joinThreadPool();
    return 0;
}
```

## Step 5: Configure the Init Script (gpiod_service.rc)

To make Android start your native service automatically on boot, create an init script:

```ini
service gpiod_service /vendor/bin/gpiod_service
    class main
    user root
    group root
```

## How Clients Access This Service

1. Native C++ Clients: Can instantly look up your service via **Service Manager** without JNI:

   ```c++
   android::sp<IBinder> binder = android::defaultServiceManager()->getService(android::String16("gpio_service"));
   android::sp<IGpioService> service = android::interface_cast<IGpioService>(binder);
   bool success = false;
   service->setPinValue(12, true, &success);
   ```

2. Java/Kotlin Apps (System Apps): Because AIDL is cross-language,  
   the exact same `.aidl` file can be compiled into Java stubs.  
   A privileged system app can connect using standard **ServiceManager** calls without writing manual JNI parsing logic.
