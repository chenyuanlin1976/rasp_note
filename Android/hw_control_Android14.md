# Hardware Control on Android 14

## 1. Hardware Control Architecture

To control a GPIO pin from an app or framework service,  
requests must pass through several layers:  

`Android App >> Binder/ ServiceManager >> Custom System Service >> Vendor HAL (AIDL) >> Kernel Driver (GPIO/ sysfs /char dev)`

Android 14 Context: Android 14 heavily relies on **AIDL (Android Interface Definition Language)** for HALs  
and enforces strict modularity through Project Treble.  
Traditional legacy HIDL interfaces are increasingly deprecated or phased out in favor of stable AIDL.

## 2. Role of ServiceManager

The **ServiceManager** acts as the central registry for all system-wide Binder services in Android.

+ Registration: A hardware-focused system service (often written in C++ or Java) registers itself  
  with the ServiceManager during boot using a unique name (e.g., "gpio_service").
+ Lookup: Clients (like higher-level framework modules or privileged system apps) query the ServiceManager  
  to retrieve a Binder proxy to that service.

## 3. Implementation Workflow

### Step 1: Define the AIDL Interface

In Android 14, define your hardware control interface using AIDL (IGpioControl.aidl):

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

int main() {.te files
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
