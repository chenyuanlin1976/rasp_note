# servicemanager from native code (`AServiceManager_*`)

`servicemanager` is the name registry for Binder services on `/dev/binder`:
a server **adds** an instance name with its binder object, and a client **looks it up** by name and gets a proxy.
Native code uses the `AServiceManager_*` functions from `libbinder_ndk`. Java platform code uses the hidden `android.os.ServiceManager`.

The full HAL that uses these calls (`.aidl`, `Android.bp`, `.rc`, VINTF, SELinux) is in [AIDL_HAL_impl.md](AIDL_HAL_impl.md),
and the GPIO version is in [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md).
This note covers only the service manager API and the rules around it.

## 1. Which service manager

| Binder device | Service manager | Registers | Native API |
| --- | --- | --- | --- |
| `/dev/binder` | `servicemanager` | Framework services, AIDL HALs | `AServiceManager_*` (this note) |
| `/dev/vndbinder` | `vndservicemanager` | Vendor ↔ vendor services, deprecated since Android 11 | cpp backend: `android::ProcessState::initWithDriver("/dev/vndbinder")`. NDK code uses stable AIDL on `/dev/binder` instead |
| `/dev/hwbinder` | `hwservicemanager` | HIDL HALs (legacy) | `IServiceManager` of HIDL |

Typical path from an app to hardware on Android 11+:

```text
3rd-party app --bindService--> system app --servicemanager lookup--> vendor AIDL HAL --> /dev/... or /sys/...
```

3rd-party apps never use `servicemanager` directly: `android.os.ServiceManager` is a hidden API, and SELinux blocks the lookup.
See [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md).

## 2. Who may add and find a service

Signing keys don't decide this. **SELinux** and, for HALs, **VINTF** decide it:

+ The instance name is labeled in `service_contexts`
  (`vendor.example.hardware.myhal.IMyHalService/default  u:object_r:hal_myhal_service:s0`).
+ `servicemanager` checks `service_manager { add }` for the server's domain and `{ find }` for the client's domain.
  For HALs, `hal_attribute_service()`, `hal_server_domain()`, and `hal_client_domain()` generate these rules.
  An unlabeled name gets `default_android_service`, and a `neverallow` forbids every access to it, so every service needs its own label.
+ A binder with **VINTF stability** (`@VintfStability`) can be added only if the instance is declared in the VINTF manifest.
  See [VINTF_intro.md](VINTF_intro.md).
+ A **native daemon** has no signing key. Its identity is the UID/GID from its `.rc` file plus its SELinux domain.
  A **platform-signed app** gets the `platform_app` / `system_app` domain (or a custom one from `seapp_contexts`),
  and it can find a HAL only if that domain is made a client with `hal_client_domain()`.
  Signing alone doesn't grant access.

Policy example: [AIDL_HAL_impl.md](AIDL_HAL_impl.md#4-selinux).

## 3. NDK API (`<android/binder_manager.h>`, `libbinder_ndk`)

These functions are in the **platform/vendor** NDK headers (`include_platform`), not in the public app NDK.

| Function | Since | Returns | Use |
| --- | --- | --- | --- |
| `AServiceManager_addService(binder, instance)` | API 29 | `binder_exception_t` (`EX_NONE` on success) | Register a service that runs all the time |
| `AServiceManager_registerLazyService(binder, instance)` | API 31 | `binder_status_t` (`STATUS_OK`) | Register a lazy service, which exits when unused and is restarted on demand by `init` |
| `AServiceManager_waitForService(instance)` | API 31 | `AIBinder*` (owned reference) | Block until the service is registered; starts lazy services |
| `AServiceManager_checkService(instance)` | API 29 | `AIBinder*` or `nullptr` | Non-blocking lookup |
| `AServiceManager_getService(instance)` | API 29 | `AIBinder*` | **Deprecated**: polls for about 5 s. Use `waitForService` or `checkService` |
| `AServiceManager_isDeclared(instance)` | API 31 | `bool` | Is this instance in the VINTF manifest? Check this before `waitForService` for an optional HAL |
| `AServiceManager_forEachDeclaredInstance(interface, ctx, cb)` | API 31 | — | Enumerate declared instances (`default`, `secondary`, ...) |
| `ABinderProcess_setThreadPoolMaxThreadCount(n)` | API 29 | `bool` | Size the Binder thread pool, before it is started |
| `ABinderProcess_startThreadPool()` / `ABinderProcess_joinThreadPool()` | API 29 | — | Start the pool / make the current thread serve calls (never returns) |

Instance names for AIDL HALs are `<package>.<Interface>/<instance>`, which is `std::string(IFoo::descriptor) + "/default"`.

## 4. Server

```c++
#define LOG_TAG "myhal-service"

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

#include "MyHalService.h"   // class MyHalService : public aidl::vendor::example::hardware::myhal::BnMyHalService

using aidl::vendor::example::hardware::myhal::MyHalService;

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(0);   // only the main thread serves calls (enough for a simple HAL)

    std::shared_ptr<MyHalService> service = ndk::SharedRefBase::make<MyHalService>();
    const std::string instance = std::string(MyHalService::descriptor) + "/default";

    binder_exception_t err = AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (err != EX_NONE) {   // SELinux "add" denied, not declared in VINTF, or a duplicate name
        ALOGE("Failed to register %s: %d", instance.c_str(), err);
        return EXIT_FAILURE;
    }

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;   // joinThreadPool() never returns
}
```

+ `SharedRefBase::make` creates the object. `asBinder()` returns the `ndk::SpAIBinder` that is passed to the service manager.
  Don't build the binder by hand with `AIBinder_Class_define`. The generated `Bn*` class does that.
+ Lazy variant: call `AServiceManager_registerLazyService()` instead.
  In the `.rc` file, add `interface aidl <instance>`, `disabled`, and `oneshot`, so that `init` starts the service on the first lookup.

## 5. Client

```c++
#include <android/binder_manager.h>
#include <aidl/vendor/example/hardware/myhal/IMyHalService.h>

using aidl::vendor::example::hardware::myhal::IMyHalService;

std::shared_ptr<IMyHalService> getHal() {
    const std::string instance = std::string(IMyHalService::descriptor) + "/default";
    if (!AServiceManager_isDeclared(instance.c_str())) {
        return nullptr;                     // this device doesn't have the HAL: don't wait forever
    }
    ndk::SpAIBinder binder(AServiceManager_waitForService(instance.c_str()));   // takes ownership
    return IMyHalService::fromBinder(binder);   // nullptr if SELinux denied "find"
}
```

Error handling for the calls themselves (`ScopedAStatus`, `EX_SERVICE_SPECIFIC`) is in [AIDL_HAL_impl.md](AIDL_HAL_impl.md#5-clients).

## 6. Java equivalents (platform code only)

| `android.os.ServiceManager` (`@hide`) | NDK |
| --- | --- |
| `addService(name, binder)` | `AServiceManager_addService` |
| `waitForService(name)` | `AServiceManager_waitForService` |
| `waitForDeclaredService(name)`: returns `null` if not declared | `isDeclared` + `waitForService` |
| `checkService(name)` | `AServiceManager_checkService` |
| `isDeclared(name)` | `AServiceManager_isDeclared` |

Only code built with the platform (`platform_apis: true`) can call these. Apps use `bindService()` and `ServiceConnection` instead.
See [Binder_svc_lookup_cmp.md](Binder_svc_lookup_cmp.md).

## 7. Debug

```shell
adb shell service list | grep myhal                       # registered?
adb shell service check vendor.example.hardware.myhal.IMyHalService/default
adb shell dumpsys -l
adb logcat -b all | grep -E 'servicemanager|avc: denied .*service_manager'
```

| Symptom | Likely cause |
| --- | --- |
| `avc: denied { add } ... tclass=service_manager` | Instance not in `service_contexts`, or the server domain lacks `hal_server_domain()` |
| `avc: denied { find } ... tclass=service_manager` | The client domain lacks `hal_client_domain()` |
| servicemanager says the instance isn't in the VINTF manifest | Manifest fragment missing, or name / version / instance mismatch |
| Client blocks forever in `waitForService` | Service not started (`.rc`, `class hal`), crashed, or not declared. Use `isDeclared()` first |

## Related notes

+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md), [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md)
+ [VINTF_intro.md](VINTF_intro.md), [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md), [Binder_svc_lookup_cmp.md](Binder_svc_lookup_cmp.md)
+ [hw_control_sysfs.md](hw_control_sysfs.md), [HAL_libgpiod.md](HAL_libgpiod.md), [SELinux_policy.md](SELinux_policy.md)

## Reference

+ [`binder_manager.h` (libbinder_ndk)](https://android.googlesource.com/platform/frameworks/native/+/main/libs/binder/ndk/include_platform/android/binder_manager.h)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [Dynamically available (lazy) AIDL HALs](https://source.android.com/docs/core/architecture/aidl/dynamic-aidl)
+ [AIDL backends (NDK)](https://source.android.com/docs/core/architecture/aidl/aidl-backends)
