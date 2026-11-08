# AIDL backends (implementation languages)

When you compile an `.aidl` file, the AIDL compiler generates **stub code** for one or more **backends**.
The stub code handles marshalling and Binder transactions.
There are **4 backends**. Kotlin is **not** a separate backend: it uses the Java backend.

## 1. Java backend (`java`)

+ Runtime: the Android framework (`android.os.Binder`).
+ Used by: apps, the framework, `system_server`.
+ Generates an `IFoo.java` with the inner classes `IFoo.Stub` (server) and `IFoo.Stub.Proxy` (client).
+ **Kotlin** code uses the same generated Java classes.
  You implement `IFoo.Stub` with Kotlin syntax (for example `object : IFoo.Stub() { ... }`).

## 2. C++ "cpp" backend (`cpp`, library `libbinder`)

+ The older C++ backend, built on `libbinder` (`android::sp<>`, `android::binder::Status`, `defaultServiceManager()`).
+ `libbinder` does **not** have a stable ABI, so both sides must be built together, from the same source tree and the same partition.
  It's fine for platform-internal services; avoid it for new code that crosses partitions.
+ Trap: the **vendor** variant of `libbinder` talks to `/dev/vndbinder` (`vndservicemanager`) by default.
  That works for vendor ↔ vendor services, but framework clients can't find the service,
  and `/dev/vndbinder` is deprecated since Android 11. Use the NDK backend instead.

## 3. C++ "ndk" backend (`ndk`, library `libbinder_ndk`)

+ The **recommended** C++ backend (`std::shared_ptr`, `ndk::ScopedAStatus`, `AServiceManager_*`).
+ `libbinder_ndk` has a stable C ABI. It is required in practice for **vendor HALs** and APEX modules.
  It is an LL-NDK library: vendor code links the system copy, which talks to `/dev/binder`.
+ **Apps** can use the NDK binder API (API 29+), but the public NDK has **no** `AServiceManager_*`.
  An app gets its `IBinder` in Java (for example from `bindService()`)
  and converts it with `AIBinder_fromJavaBinder()` (`<android/binder_ibinder_jni.h>`).
+ Generated headers live under `aidl/<package path>/` (for example `<aidl/com/example/IFoo.h>`).

## 4. Rust backend (`rust`, library `libbinder_rs`)

+ Supported since **Android 12**, for memory-safe system services, daemons, and HALs.

## 5. Summary

| Backend | Language | Binder library | Typical use | Stable ABI |
| --- | --- | --- | --- | --- |
| `java` | Java / Kotlin | `android.os.Binder` | Apps, framework services | n/a |
| `cpp` | C++ | `libbinder` | Platform-internal native services (system partition) | No |
| `ndk` | C++ | `libbinder_ndk` | Vendor HALs, APEX, mainline modules, NDK apps | **Yes** |
| `rust` | Rust | `libbinder_rs` | Memory-safe system services / HALs | Uses `libbinder_ndk` underneath |

In `Android.bp`, backends are enabled per `aidl_interface`. The generated library names are
`<name>-V<n>-java`, `<name>-V<n>-cpp`, `<name>-V<n>-ndk`, and `<name>-V<n>-rust`.
For an `unstable: true` interface, there is no version suffix: `<name>-java`, `<name>-ndk`, and so on.

## Related notes

+ [AIDL_intro.md](AIDL_intro.md)
+ [AIDL_ndk_led_sysfs.md](AIDL_ndk_led_sysfs.md), [../HAL/AIDL_HAL_gpio.md](../HAL/AIDL_HAL_gpio.md): NDK backend examples
+ [AIDL_app_bound_svc.md](AIDL_app_bound_svc.md): Java/Kotlin example

## Reference

+ [AIDL backends](https://source.android.com/docs/core/architecture/aidl/aidl-backends)
