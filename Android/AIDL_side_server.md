# native HAL

Writing the server-side implementation for a C++ native HAL in AOSP using AIDL  
involves implementing the generated C++ interface class, creating a service context (binder::ProcessState),  
and registering your service with the ServiceManager so clients can find it.

Here is a step-by-step guide to setting up and writing your C++ native AIDL HAL service.

## 1. Understand the Generated C++ Class

When you define an AIDL file (e.g., `IMyHalService.aidl`) and build it, the build system generates a C++ base class.  
If your package is `vendor.example.hardware.myhal`,  
the generated header will typically be located in the intermediate build directory as:
`#include <aidl/vendor/example/hardware/myhal/BnMyHalService.h>`

Your server needs to create a class that **inherits** from this Bnxxx (Binder Native) class and **overrides** your custom methods.

## 2. Implement the Service Class (MyHalService.h & MyHalService.cpp)

### Header File (MyHalService.h)

```c++
#pragma once

#include <aidl/vendor/example/hardware/myhal/BnMyHalService.h>

namespace aidl::vendor::example::hardware::myhal {

class MyHalService : public BnMyHalService {
public:
    MyHalService();
    virtual ~MyHalService() = default;

    // Override the methods defined in your AIDL file
    ::ndk::ScopedAStatus doSomething(int32_t in_param, int32_t* _aidl_return) override;
};

} // namespace aidl::vendor::example::hardware::myhal
```

### Implementation File (MyHalService.cpp)

```c++
#include "MyHalService.h"
#include <android/log.h>

#define LOG_TAG "MyHalService"

namespace aidl::vendor::example::hardware::myhal {

MyHalService::MyHalService() {
    ALOGI("MyHalService created");
}

::ndk::ScopedAStatus MyHalService::doSomething(int32_t in_param, int32_t* _aidl_return) {
    ALOGI("doSomething called with param: %d", in_param);
    
    // Perform your HAL operations here
    *_aidl_return = in_param * 2; 

    return ::ndk::ScopedAStatus::ok();
}

} // namespace aidl::vendor::example::hardware::myhal
```

## 3. Write the Service Entry Point (main.cpp)

Your executable needs to instantiate your service, configure the thread pool,  
and register the service with the ServiceManager using its fully qualified descriptor name.

```c++
#include "MyHalService.h"
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <android/log.h>

#define LOG_TAG "MyHalServiceMain"

using aidl::vendor::example::hardware::myhal::MyHalService;

int main() {
    ALOGI("Starting MyHalService...");

    // Enable binder thread pool for handling incoming calls
    ABinderProcess_setThreadPoolMaxThreadCount(0); // Set > 0 if you want multithreading

    // Instantiate your service using ndk::SharedRefBase
    std::shared_ptr<MyHalService> service = ndk::SharedRefBase::make<MyHalService>();

    // Define the service name typically registered in servicemanager
    const std::string instance = std::string() + MyHalService::descriptor + "/default";

    // Register the service
    binder_status_t status = AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (status != STATUS_OK) {
        ALOGE("Failed to register service %s, status: %d", instance.c_str(), status);
        return -1;
    }

    ALOGI("MyHalService registered successfully. Joining thread pool...");
    ABinderProcess_joinThreadPool();

    return EXIT_FAILURE; // Should not reach here
}
```

## 4. Configure the Build File (Android.bp)

To build your native C++ service, write an `Android.bp` in your HAL directory.  
Ensure you link against the C++ AIDL backend library (-ndk suffix).

```ini
cc_binary {
    name: "vendor.example.hardware.myhal-service",
    init_rc: ["vendor.example.hardware.myhal-service.rc"],
    vintf_fragments: ["vendor.example.hardware.myhal-service.xml"],
    vendor: true,
    
    srcs: [
        "MyHalService.cpp",
        "main.cpp",
    ],

    shared_libs: [
        "libbase",
        "libbinder_ndk",
        "android.hardware.common-V2-ndk", // Include if using common AIDL types
        "vendor.example.hardware.myhal-ndk", // This is your generated AIDL library
    ],
}
```

## 5. Add Init Script (.rc) and VINTF Manifest

To ensure your HAL starts automatically on boot and passes VINTF compliance:  

### vendor.example.hardware.myhal-service.rc

```ini
service vendor.example.hardware.myhal-service /vendor/bin/hw/vendor.example.hardware.myhal-service
    class hal
    user system
    group system
```

### vendor.example.hardware.myhal-service.xml (VINTF Manifest)

```xml
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>vendor.example.hardware.myhal</name>
        <version>1</version>
        <interface>
            <name>IMyHalService</name>
            <instance>default</instance>
        </interface>
    </hal>
</manifest>
```

## Quick Check

+ Did you include `vendor: true` in your `Android.bp` so it builds for the vendor partition?
+ Is your service name format structured as `[Package].[Interface]/default`?
