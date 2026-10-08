# AIDL client side

To connect to your C++ native HAL from the client side (such as an Android application, a Java/Kotlin system service, or even a native C++ client),  
you need to retrieve the service instance through Android's **ServiceManager** using the exact name you registered in your server implementation.

Here is how to implement the client side across different environments:

## Method 1: Client in Java / Kotlin (App or System Service)

If your client is running in the Android framework (like an app or a system service),  
AIDL automatically generates Java/Kotlin bindings if your .aidl file is part of an aidl_interface module.

### 1. Update Android.bp (if not already done)

Ensure your module depends on the Java/Kotlin-backed AIDL library:

```ini
android_app {
    name: "MyHalClientApp",
    srcs: ["src/**/*.java"],
    // ...
    static_libs: [
        "vendor.example.hardware.myhal-V1-java", // Generated Java backend library
    ],
}
```

### 2. Get the Service and Call Methods

In your Java or Kotlin code, use **ServiceManager** to connect the **HAL service**  
using its descriptor and instance name (default).

```kotlin
import android.os.ServiceManager
import vendor.example.hardware.myhal.IMyHalService

// 1. Fetch the service binder safely
val binder = ServiceManager.waitForService("${IMyHalService.DESCRIPTOR}/default")

if (binder != null) {
    // 2. Cast the binder to your AIDL interface
    val myHalService = IMyHalService.Stub.asInterface(binder)

    try {
        // 3. Call your HAL method
        val result = myHalService.doSomething(42)
        android.util.Log.d("MyHalClient", "Result from HAL: $result")
    } catch (e: Exception) {
        android.util.Log.e("MyHalClient", "Failed to call HAL method", e)
    }
} else {
    android.util.Log.e("MyHalClient", "Failed to find MyHalService!")
}
```

## Method 2: Client in Native C++ (Another HAL or Native Service)

If your client is another native C++ process  
(e.g., a system daemon or wrapper HAL), it will use the NDK backend.

### 1. Update Android.bp

Include the -ndk shared library in your client binary/library:

```ini
cc_binary {
    name: "my_native_hal_client",
    srcs: ["client_main.cpp"],
    shared_libs: [
        "libbinder_ndk",
        "vendor.example.hardware.myhal-ndk",
    ],
}
```

### 2. Implementation Code (client_main.cpp)

Use **AServiceManager_waitForService** to locate and bind to the service:

```c++
#include <android/binder_manager.h>
#include <aidl/vendor/example/hardware/myhal/IMyHalService.h>
#include <android/log.h>

#define LOG_TAG "MyHalClient"

using aidl::vendor::example::hardware::myhal::IMyHalService;

int main() {
    // Build the exact instance name used in the server
    std::string instanceName = std::string() + IMyHalService::descriptor + "/default";

    ALOGI("Waiting for service: %s", instanceName.c_str());

    // Wait for the service to become available
    AIBinder* binder = AServiceManager_waitForService(instanceName.c_str());
    if (binder == nullptr) {
        ALOGE("Failed to get service binder!");
        return -1;
    }

    // Convert the raw AIBinder pointer to the smart-pointer NDK interface type
    std::shared_ptr<IMyHalService> service = IMyHalService::fromBinder(ndk::SpAIBinder(binder));
    if (service == nullptr) {
        ALOGE("Failed to cast binder to IMyHalService!");
        return -1;
    }

    // Call the method
    int32_t outResult = 0;
    ::ndk::ScopedAStatus status = service->doSomething(42, &outResult);

    if (status.isOk()) {
        ALOGI("Successfully called HAL! Result: %d", outResult);
    } else {
        ALOGE("HAL call failed with exception code: %d", status.getExceptionCode());
    }

    return 0;
}
```

## Crucial Security Note (SELinux Permissions)

When writing a new client and server in AOSP,  
you will almost certainly run into SELinux denials if permissions aren't properly defined.

1. Client Context: Ensure your client app/process has permission to find the service context in your `.te` policy files.
2. Service Context: Ensure your server service name is registered in service_contexts:

`vendor.example.hardware.myhal.IMyHalService/default u:object_r:vendor_myhal_service:s0`
