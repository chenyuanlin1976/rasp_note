# AIDL native C++ HAL: server and client

This note builds a complete **vendor AIDL HAL** with the **NDK backend** (`libbinder_ndk`):
interface → server → init/VINTF → SELinux → clients.
All names follow one example interface:

| Item | Value |
| --- | --- |
| AIDL package / `aidl_interface` name | `vendor.example.hardware.myhal` |
| Interface | `IMyHalService` |
| Service instance name | `vendor.example.hardware.myhal.IMyHalService/default` |
| Generated NDK library | `vendor.example.hardware.myhal-V1-ndk` |
| Executable | `/vendor/bin/hw/vendor.example.hardware.myhal-service` |

Directory layout:

```text
vendor/example/hardware/myhal/
├── aidl/
│   ├── Android.bp
│   ├── vendor/example/hardware/myhal/IMyHalService.aidl
│   └── aidl_api/vendor.example.hardware.myhal/1/...      # created by "m ...-freeze-api"
└── default/
    ├── Android.bp
    ├── MyHalService.h / MyHalService.cpp / main.cpp
    ├── vendor.example.hardware.myhal-service.rc
    └── vendor.example.hardware.myhal-service.xml
```

## 1. The interface (`aidl/`)

```java
// aidl/vendor/example/hardware/myhal/IMyHalService.aidl
package vendor.example.hardware.myhal;

@VintfStability
interface IMyHalService {
    int doSomething(int param);
}
```

```bp
// aidl/Android.bp
aidl_interface {
    name: "vendor.example.hardware.myhal",
    vendor_available: true,          // vendor modules may link the generated libs
    srcs: ["vendor/example/hardware/myhal/*.aidl"],
    stability: "vintf",              // required for a HAL; needs @VintfStability in the .aidl
    backend: {
        cpp:  { enabled: false },
        java: { enabled: true, sdk_version: "module_current" },   // for framework Java clients
        ndk:  { enabled: true },
    },
    versions_with_info: [
        { version: "1", imports: [] },
    ],
    frozen: true,
}
```

+ The block above shows the state **after** v1 is frozen.
  During development, leave out `versions_with_info`/`frozen` and run `m vendor.example.hardware.myhal-update-api` after you edit the `.aidl` file.
  To release v1, run `m vendor.example.hardware.myhal-freeze-api`.
  This creates `aidl_api/.../1/` and fills in `versions_with_info`.
  The `frozen:` property exists since Android 14; older trees use only `versions_with_info` (or `versions`).
+ The generated libraries are named with the version, for example `vendor.example.hardware.myhal-V1-ndk`.
  Clients link a specific version. A newer server must keep answering the old version's methods.

## 2. The server (`default/`)

The build generates `BnMyHalService` ("Binder native").
The header is `<aidl/vendor/example/hardware/myhal/BnMyHalService.h>`, and its namespace starts with `aidl::`.
Your class inherits from `BnMyHalService` and overrides the methods.
The return type is always `ndk::ScopedAStatus`, and the AIDL return value becomes the last pointer argument, `_aidl_return`.

### MyHalService.h

```c++
#pragma once

#include <aidl/vendor/example/hardware/myhal/BnMyHalService.h>

namespace aidl::vendor::example::hardware::myhal {

class MyHalService : public BnMyHalService {
  public:
    ndk::ScopedAStatus doSomething(int32_t in_param, int32_t* _aidl_return) override;
};

}  // namespace aidl::vendor::example::hardware::myhal
```

### MyHalService.cpp

```c++
#define LOG_TAG "MyHalService"   // must come before <log/log.h>

#include "MyHalService.h"
#include <log/log.h>

namespace aidl::vendor::example::hardware::myhal {

ndk::ScopedAStatus MyHalService::doSomething(int32_t in_param, int32_t* _aidl_return) {
    ALOGI("doSomething(%d)", in_param);
    if (in_param < 0) {
        // Errors go in the status; the client sees ServiceSpecificException / getServiceSpecificError()
        return ndk::ScopedAStatus::fromServiceSpecificError(1 /* ERROR_BAD_PARAM */);
    }
    *_aidl_return = in_param * 2;
    return ndk::ScopedAStatus::ok();
}

}  // namespace aidl::vendor::example::hardware::myhal
```

### main.cpp

```c++
#define LOG_TAG "MyHalServiceMain"

#include "MyHalService.h"
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

using aidl::vendor::example::hardware::myhal::MyHalService;

int main() {
    // 0 extra threads: the main thread (joinThreadPool below) is the only binder thread.
    // For concurrency, set N > 0 AND call ABinderProcess_startThreadPool().
    ABinderProcess_setThreadPoolMaxThreadCount(0);

    std::shared_ptr<MyHalService> service = ndk::SharedRefBase::make<MyHalService>();

    // "<descriptor>/<instance>" must match the VINTF manifest and service_contexts
    const std::string instance = std::string(MyHalService::descriptor) + "/default";

    binder_exception_t err = AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (err != EX_NONE) {
        ALOGE("Failed to register %s: %d", instance.c_str(), err);
        return EXIT_FAILURE;
    }

    ALOGI("%s registered", instance.c_str());
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;   // joinThreadPool() never returns
}
```

### default/Android.bp

```bp
cc_binary {
    name: "vendor.example.hardware.myhal-service",
    relative_install_path: "hw",      // -> /vendor/bin/hw/
    vendor: true,
    init_rc: ["vendor.example.hardware.myhal-service.rc"],
    vintf_fragments: ["vendor.example.hardware.myhal-service.xml"],
    srcs: [
        "MyHalService.cpp",
        "main.cpp",
    ],
    shared_libs: [
        "libbase",
        "libbinder_ndk",
        "liblog",
        "vendor.example.hardware.myhal-V1-ndk",
    ],
}
```

Add the service to the product: `PRODUCT_PACKAGES += vendor.example.hardware.myhal-service`.

## 3. Init script and VINTF

### vendor.example.hardware.myhal-service.rc

```text
service vendor.example.hardware.myhal-service /vendor/bin/hw/vendor.example.hardware.myhal-service
    class hal
    user system
    group system
```

### vendor.example.hardware.myhal-service.xml (device manifest fragment)

```xml
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>vendor.example.hardware.myhal</name>
        <version>1</version>
        <fqname>IMyHalService/default</fqname>
    </hal>
</manifest>
```

A HAL that the manifest declares must also be listed in a **compatibility matrix**.
Otherwise the VINTF check fails at build time or on boot.
For a vendor HAL, add it to the device framework compatibility matrix (`DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE`):

```xml
<compatibility-matrix version="1.0" type="framework">
    <hal format="aidl" optional="true">
        <name>vendor.example.hardware.myhal</name>
        <version>1</version>
        <interface>
            <name>IMyHalService</name>
            <instance>default</instance>
        </interface>
    </hal>
</compatibility-matrix>
```

## 4. SELinux

**Where the policy goes depends on who the clients are.**
Platform policy (system, system_ext, product) can't reference types that are defined in **vendor** policy.

+ If all clients are vendor processes, everything can live in vendor policy.
+ If **any client is on the system side** (a system app, `system_server`, a system_ext daemon),
  the HAL attribute and the service type must be defined in a **public** policy directory that both sides see.
  For a device-specific HAL that is `system_ext/public` (`SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS`).

```text
# system_ext/public/hal_myhal.te: shared by vendor (server) and system_ext (clients)
hal_attribute(myhal)                         # creates hal_myhal, hal_myhal_client, hal_myhal_server
type hal_myhal_service, hal_service_type, protected_service, service_manager_type;
hal_attribute_service(hal_myhal, hal_myhal_service)   # server may add, clients may find

# vendor/hal_myhal_default.te: the server domain
type hal_myhal_default, domain;
hal_server_domain(hal_myhal_default, hal_myhal)
type hal_myhal_default_exec, exec_type, vendor_file_type, file_type;
init_daemon_domain(hal_myhal_default)

# vendor/file_contexts
/vendor/bin/hw/vendor\.example\.hardware\.myhal-service  u:object_r:hal_myhal_default_exec:s0

# vendor/service_contexts
vendor.example.hardware.myhal.IMyHalService/default     u:object_r:hal_myhal_service:s0

# in the policy of each client domain (vendor or system_ext/private)
hal_client_domain(my_client_domain, hal_myhal)
```

`protected_service` marks the service as one that only declared HAL clients may find.
Debug denials with `adb logcat | grep avc` (see [../SELinux/avc_denied.md](../SELinux/avc_denied.md)).

## 5. Clients

### 5.1 Native C++ client (NDK backend)

```bp
cc_binary {
    name: "my_native_hal_client",
    vendor: true,
    srcs: ["client_main.cpp"],
    shared_libs: ["libbinder_ndk", "liblog", "vendor.example.hardware.myhal-V1-ndk"],
}
```

```c++
#define LOG_TAG "MyHalClient"

#include <aidl/vendor/example/hardware/myhal/IMyHalService.h>
#include <android/binder_manager.h>
#include <log/log.h>

using aidl::vendor::example::hardware::myhal::IMyHalService;

int main() {
    const std::string instance = std::string(IMyHalService::descriptor) + "/default";

    // Blocks until the service is registered (it can wait forever if the HAL never starts).
    // Returns nullptr if SELinux denies "find".
    // For VINTF HALs, check AServiceManager_isDeclared(instance) first if the HAL is optional on some devices.
    ndk::SpAIBinder binder(AServiceManager_waitForService(instance.c_str()));
    std::shared_ptr<IMyHalService> hal = IMyHalService::fromBinder(binder);
    if (hal == nullptr) {
        ALOGE("Cannot get %s", instance.c_str());
        return EXIT_FAILURE;
    }

    int32_t result = 0;
    ndk::ScopedAStatus status = hal->doSomething(42, &result);
    if (status.isOk()) {
        ALOGI("Result: %d", result);
    } else if (status.getExceptionCode() == EX_SERVICE_SPECIFIC) {
        ALOGE("HAL error %d", status.getServiceSpecificError());
    } else {
        ALOGE("Binder failure: %s", status.getDescription().c_str());
    }
    return EXIT_SUCCESS;
}
```

### 5.2 Java client (framework / platform-signed system app)

`android.os.ServiceManager` is a **hidden API**, so this code works only in platform code
(`system_server`, or an app built with `platform_apis: true` and signed with the platform key).
3rd-party apps can't reach a vendor HAL; see [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md).

```bp
android_app {
    name: "MyHalClientApp",
    srcs: ["src/**/*.kt"],
    platform_apis: true,
    certificate: "platform",
    privileged: true,
    static_libs: ["vendor.example.hardware.myhal-V1-java"],
}
```

```kotlin
import android.os.RemoteException
import android.os.ServiceManager
import android.os.ServiceSpecificException
import android.util.Log
import vendor.example.hardware.myhal.IMyHalService

val name = "${IMyHalService.DESCRIPTOR}/default"
val binder = ServiceManager.waitForDeclaredService(name)   // null if not in VINTF manifest
val hal = IMyHalService.Stub.asInterface(binder)

try {
    val result = hal?.doSomething(42)
    Log.d("MyHalClient", "Result from HAL: $result")
} catch (e: ServiceSpecificException) {
    Log.e("MyHalClient", "HAL error ${e.errorCode}")
} catch (e: RemoteException) {
    Log.e("MyHalClient", "HAL died / binder error", e)
}
```

The app's SELinux domain (for example `platform_app`, or a custom domain) also needs `hal_client_domain(<domain>, hal_myhal)`.
Put that rule in `system_ext/private`, which works because `hal_myhal` is in `system_ext/public` (see section 4).
`neverallow` rules may forbid this for some app domains; in that case, put the access in a system service instead.

## 6. Quick checklist

+ [ ] `.aidl` has `@VintfStability`, and `aidl_interface` has `stability: "vintf"` and a frozen version
+ [ ] Server links `...-V1-ndk`, `vendor: true`, `relative_install_path: "hw"`
+ [ ] Instance name `<package>.<Interface>/default` is **identical** in `main.cpp`, the VINTF manifest, `service_contexts`, and the clients
+ [ ] Manifest fragment + compatibility matrix entry
+ [ ] SELinux: `hal_attribute`, `hal_server_domain`, `hal_attribute_service`, `hal_client_domain`
+ [ ] On device: `adb shell service list | grep myhal` and `adb shell dumpsys -l | grep myhal`

## Related notes

+ [AIDL_HAL_intro.md](AIDL_HAL_intro.md): concept and the "contract"
+ [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md), [../IPC/AIDL_ndk_led_sysfs.md](../IPC/AIDL_ndk_led_sysfs.md): hardware examples
+ [VINTF_intro.md](VINTF_intro.md), [../SELinux/SELinux_policy.md](../SELinux/SELinux_policy.md), [../IPC/Binder_svc_lookup_cmp.md](../IPC/Binder_svc_lookup_cmp.md)
+ [../IPC/ServiceManager_ndk.md](../IPC/ServiceManager_ndk.md): `AServiceManager_*` API, add/find rules, lazy services

## Reference

+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [Stable AIDL](https://source.android.com/docs/core/architecture/aidl/stable-aidl)
+ [AIDL backends: NDK](https://source.android.com/docs/core/architecture/aidl/aidl-backends)
