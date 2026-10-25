# Hardware Control on Android 14

## 1. Hardware Control Architecture

To control a GPIO pin from an app or framework service,  
requests must pass through several layers:  

`Android App >> Binder/ ServiceManager >> Custom System Service >> Vendor HAL (AIDL) >> Kernel Driver (GPIO/ sysfs /char dev)`

Android 14 Context: Android 14 heavily relies on **AIDL (Android Interface Definition Language)** for HALs  
and enforces strict modularity through Project Treble.  
Traditional legacy HIDL interfaces are increasingly **deprecated** or phased out in favor of stable AIDL.

## 2. Role of ServiceManager

The **ServiceManager** acts as the central registry for all system-wide Binder services in Android.

+ Registration: A hardware-focused system service (often written in C++ or Java) registers itself  
  with the ServiceManager during boot using a unique name (e.g., "gpio_service").
+ Lookup: Clients (like higher-level framework modules or privileged system apps) query the ServiceManager  
  to retrieve a Binder proxy to that service.

## 3. Implementation Workflow

### Step 1: Define the AIDL Interface

In Android 14, define your hardware control interface using AIDL (`IGpioControl.aidl`):

```java
package android.hardware.gpio;

interface IGpioControl {
    boolean setGpioOutput(int pin, boolean high);
}
```

### Step 2: Implement the Native/C++ Service and Register with ServiceManager

In your system daemon or service implementation, you register the service with ServiceManager:

```c++
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include "android/hardware/gpio/BnGpioControl.h"

class GpioControlService : public android::hardware::gpio::BnGpioControl {
    ::ndk::ScopedAStatus setGpioOutput(int pin, bool high, bool* _aidl_return) override {
        // Low-level control implementation (e.g., writing to a character device or sysfs)
        // Example: write to /dev/gpiodev or /sys/class/gpio/...
        *_aidl_return = true;
        return ::ndk::ScopedAStatus::ok();
    }
};

int main() {
    ABinderProcess_setThreadPoolMaxThreadModel(1);
    
    std::shared_ptr<GpioControlService> gpioService = ndk::SharedRefBase::make<GpioControlService>();
    const std::string instance = std::string(GpioControlService::descriptor) + "/default";
    
    // Register with ServiceManager
    binder_exception_t status = AServiceManager_addService(gpioService->asBinder().get(), instance.c_str());
    
    ABinderProcess_joinThreadPool();
    return EXIT_SUCCESS;
}
```

### Step 3: Accessing the Service via ServiceManager from a Client

If you have a **privileged system component** or a built-in app with the appropriate system/root signatures,  
you can fetch the service via ServiceManager (or ServiceManagerNative in Java) and trigger the GPIO change:

```java
// Java / Framework side example (requires system privileges)
IBinder binder = ServiceManager.getService("android.hardware.gpio.IGpioControl/default");
IGpioControl gpioControl = IGpioControl.Stub.asInterface(binder);

if (gpioControl != null) {
    boolean success = gpioControl.setGpioOutput(12, true); // Set GPIO 12 HIGH
}
```

### 4. Android 14 Security & Permissions Restrictions

+ SELinux Policies: Android 14 enforces rigorous domain separation.  
  Your native daemon and the context executing the GPIO writes must have explicit custom SELinux policy rules (**.te files**)  
  defined in the device tree, otherwise access to /dev/* or sysfs nodes will be blocked instantly with Permission Denied.
+ SELinux Domain Transitions: Regular apps (untrusted_app) cannot talk directly to custom hardware Binder services  
  unless granted signature-level permissions or custom platform privileges (android:sharedUserId="android.uid.system" or privileged system apps).
+ Kernel Layer: Ultimately, the hardware control code opens the Linux GPIO character device (/dev/gpiochipN) using standard kernel APIs  
  (gpiod_* ioctls introduced by the modern Linux GPIO subsystem) to drive the physical pin state.

## platform key

Ggaining permission to control hardware via **ServiceManager** on Android 14  
typically requires signing your app or service with the **platform key**  
(or running as a built-in system component like system, root, or shell).

Because Android enforces strict security boundaries,  
standard application keys cannot access custom hardware Binder services or privileged ServiceManager registrations.

### Why the Platform Key is Needed

+ SELinux Context: Custom hardware services and low-level device nodes (/dev/*) are restricted by SELinux.  
  Only specific high-privilege domains (such as system_server, init, or custom platform daemons signed with specific keys)  
  are permitted to interact with these nodes.
+ ServiceManager Protection: While any process can technically read or query a service,  
  registering a new hardware control service or accessing protected Binder interfaces requires explicit permissions  
  and system-level UID assignment (e.g., `android.uid.system`).
+ Signature Protection Levels: In your AIDL or service definition, you can specify permission checks.  
  If you want to restrict who can call setGpioOutput, you define a permission with `protectionLevel="signature"`,  
  meaning only apps signed with the same platform key as the OS build can call it.

## Alternative Approaches

If you do not want to or cannot sign your entire OS image with a custom platform key,  
you have a few alternatives depending on your deployment scenario:

1. AOSP Custom Build/ OEM Control: If you are building the Android 14 firmware yourself for an embedded board  
   (like NXP, Qualcomm, or Raspberry Pi CM4), you compile your native daemon directly into the OS image, signed with the device's platform keys.
2. Root Access (For Development/Testing): On a rooted engineering build or userdebug build,  
   you can bypass certain SELinux restrictions or run scripts/binferences as root to test ServiceManager calls directly,  
   though this is insecure for production.
3. Vendor HAL (AIDL): Exposing the functionality via a proper vendor AIDL interface (android.hardware.*) allows privileged system apps  
   or modules to call it, but the HAL implementation itself still runs with vendor/system privileges requiring correct signing and SELinux policies.

## Overview of `AServiceManager_addService`

`AServiceManager_addService` is a C/C++ API function introduced in Android 10 (API level 29)  
as part of the Native C++ API for the Android **Service Manager**.  
It allows native C/C++ daemons, HALs (Hardware Abstraction Layers), and system services  
to **register a Binder service** with the system-wide **Service Manager**  
so that other processes can discover and communicate with it.

### Function Signature & Parameters

While the exact headers may vary slightly by NDK/platform version,  
its standard definition in the Android source tree (typically found in binder/`IServiceManager.h`  
or via the NDK's `android/service_manager.h`) looks like this:

`binder_status_t AServiceManager_addService(AIBinder* binder, const char* instanceName);`

#### Parameters

1. `AIBinder* binder`:  
   + A pointer to the local Binder object (the service implementation) that you want to publish.  
     This object must be created using the NDK Binder API (e.g., via a death recipient or a custom AIBinder_Class implementation).
2. `const char* instanceName`:
   + The string identifier of the service (e.g., "media.player" or "android.hardware.sensors.ISensors/default").  
     This name must match the name that clients will use when calling `AServiceManager_checkService`  
     or `AServiceManager_getService` to look up the service.

#### Return Value

Returns a `binder_status_t` status code  
(e.g., `STATUS_OK` on success, or an error code like `STATUS_NAME_NOT_FOUND`, `STATUS_PERMISSION_DENIED`, etc., on failure).

### How It Works Under the Hood

+ Native Binder Integration:  
  Prior to Android's Native Binder NDK support,  
  registering services required writing C++ code using internal libbinder headers (`android::IServiceManager::addService`).  
  `AServiceManager_addService` provides a stable, public NDK API that doesn't depend on internal platform headers.
+ IPC Communication with servicemanager:  
  When you call this function, the NDK sends a transaction over the `/dev/binder` driver to the central servicemanager process,  
  registering the mapping between the provided instanceName and your AIBinder reference.
+ SELinux Permissions:  
  The calling process must have the appropriate **SELinux policy permissions** to add a service.  
  If the domain of your native process is not allowed to register services with the given name,  
  the Service Manager will reject the request with a permission error.

### Code Example (Native C++ Usage)

Here is a simplified example showing how a native service is created and registered using the NDK Binder API:

```c
#include <android/binder_interface_utils.h>
#include <android/binder_servicemanager.h>
#include <android/binder_ibinder.h>

// Define your binder class (callback/methods implementation)
static AIBinder_Class* kMyServiceClass = AIBinder_Class_define(
    "com.example.IMyNativeService",
    [](AIBinder_Class* clazz) {
        // Constructor / Destructor / OnTransact handlers go here
    },
    [](AIBinder* binder) {}, // onCreat
    [](AIBinder* binder) {}  // onDestroy
);

void publishMyService() {
    // 1. Create an instance of your binder object
    AIBinder* binder = AIBinder_new(kMyServiceClass, nullptr);

    // 2. Register the service with the Android Service Manager
    binder_status_t status = AServiceManager_addService(binder, "com.example.IMyNativeService/default");

    if (status == STATUS_OK) {
        // Service successfully published!
    } else {
        // Handle failure (e.g., SELinux denial or service manager not ready)
    }

    // Drop local reference if ownership is handed over or managed accordingly
    AIBinder_decStrong(binder);
}
```

### Common Use Cases

+ Native Daemons: Background system daemons written in C++ that need to expose APIs to Java applications or other native components.
+ HIDL/ AIDL HAL Implementations: Hardware abstraction layer services running in native space  
  that need to be reachable by Android framework services (like AudioFlinger, SurfaceFlinger, etc.).
