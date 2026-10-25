# Using Pure C++ AIDL

Using Pure C++ AIDL (the **NDK** backend) means you write **both the client and the service entirely in C++**.  
There is no Java Virtual Machine, no ART, and zero JNI overhead.

Android supports this natively via the NDK backend (ndk), which generates C++ classes and headers directly from your `.aidl` files.

Here is a complete end-to-end example of implementing a **pure C++ AIDL service** that controls the LED sysfs nodes.

## Step 1: The AIDL File (ILedControl.aidl)

The .aidl file remains identical regardless of whether you use Java or C++.

```java
package com.example.led;

interface ILedControl {
    void setLedState(int controlState, int delayOn, int delayOff);
}
```

## Step 2: The Build File (Android.bp)

In your AOSP source tree or native module,  
configure the `Android.bp` file to generate the C++ (NDK) backend bindings:

```json
aidl_interface {
    name: "ILedControl",
    srcs: ["ILedControl.aidl"],
    stability: "vintf", // Optional: use vintf if this is a hardware service / HAL
    backend: {
        ndk: {
            enabled: true, // Enables the C++ NDK backend generation
        },
    },
}
```

When built, Android's build system automatically generates C++ headers  
(e.g., `#include <aidl/com/example/led/BnLedControl.h>`).

## Step 3: Implement the C++ Service (LedControlService.cpp)

Your C++ service inherits directly from the generated C++ base class (`BnLedControl`) and overrides its methods.

```c++
#include <aidl/com/example/led/BnLedControl.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <fstream>
#include <string>

using aidl::com::example::led::BnLedControl;
using ndk::ScopedAStatus;

class LedControlService : public BnLedControl {
public:
    ScopedAStatus setLedState(int32_t controlState, int32_t delayOn, int32_t delayOff) override {
        if (controlState == 0) {
            // OFF
            writeToFile("/sys/class/leds/sys_led_r/trigger", "none");
            writeToFile("/sys/class/leds/sys_led_r/brightness", "0");
        } 
        else if (controlState == 1) {
            // ON
            writeToFile("/sys/class/leds/sys_led_r/trigger", "none");
            writeToFile("/sys/class/leds/sys_led_r/brightness", "255");
        } 
        else if (controlState == 2) {
            // BLINK (Kernel Timer)
            writeToFile("/sys/class/leds/sys_led_r/trigger", "timer");
            writeToFile("/sys/class/leds/sys_led_r/delay_on", std::to_string(delayOn));
            writeToFile("/sys/class/leds/sys_led_r/delay_off", std::to_string(delayOff));
        }
        
        return ScopedAStatus::ok();
    }

private:
    void writeToFile(const std::string& path, const std::string& value) {
        std::ofstream file(path);
        if (file.is_open()) {
            file << value;
        }
    }
};
```

## Step 4: Register and Start the Native Service (main.cpp)

To make your C++ service available to the Android system via **Binder**,  
you instantiate it and register it with the Android `AServiceManager`:

```c++
#include "LedControlService.cpp" // or include your header file

int main() {
    // Initialize the binder thread pool for handling incoming IPC calls
    ABinderProcess_setThreadPoolMaxThreadCount(0);

    // Create an instance of your native service using NDK smart pointers
    std::shared_ptr<LedControlService> service = ndk::SharedRefBase::make<LedControlService>();

    // Register the service with ServiceManager using the standard descriptor naming convention
    const std::string instanceName = std::string(LedControlService::descriptor) + "/default";
    binder_exception_t status = AServiceManager_addService(service->asBinder().get(), instanceName.c_str());

    if (status != STATUS_OK) {
        // Handle registration failure
        return EXIT_FAILURE;
    }

    // Join the thread pool so the process stays alive and listens for binder calls
    ABinderProcess_joinThreadPool();
    
    return EXIT_FAILURE; // Should never reach here
}
```

## Step 5: How a Native C++ Client Calls It

If another native daemon or process wants to call this service,  
it doesn't need Kotlin or Java either - it can look it up entirely in C++:

```c++
#include <aidl/com/example/led/ILedControl.h>
#include <android/binder_manager.h>

using aidl::com::example::led::ILedControl;

void triggerBlinkFromNativeCode() {
    std::string instanceName = std::string(ILedControl::descriptor) + "/default";
    
    // Connect to the service via Binder
    std::shared_ptr<ILedControl> ledService = ILedControl::fromBinder(
        ndk::SpAIBinder(AServiceManager_checkService(instanceName.c_str()))
    );

    if (ledService != nullptr) {
        // Directly invoke the method over Binder IPC—no JNI involved!
        ledService->setLedState(2, 500, 500); // 500ms on, 500ms off blink
    }
}
```

## Why Choose Pure C++ AIDL?

+ Zero Overhead: No JVM translation, no JNI type conversion (jstring, jint, etc.), and minimal memory footprint.
+ Ideal for System Daemons: Perfect for low-level AOSP native services, hardware abstraction layers (HALs),  
  or vendor daemons that run outside the Android framework runtime.
