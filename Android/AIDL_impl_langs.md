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
+ `libbinder` does **not** have a stable ABI, so use this backend only for code built with the platform (in the `system` partition).
+ Trap: on the **vendor** partition, `libbinder` talks to `/dev/vndbinder` (`vndservicemanager`) by default,
  so framework clients can't find the service.

## 3. C++ "ndk" backend (`ndk`, library `libbinder_ndk`)

+ The **recommended** C++ backend (`std::shared_ptr`, `ndk::ScopedAStatus`, `AServiceManager_*`).
+ `libbinder_ndk` has a stable C ABI. It is required in practice for **vendor HALs** and APEX modules,
  and it is in the public NDK (API 29+), so apps can use it too.
+ Generated headers live under `aidl/<package path>/` (for example `<aidl/com/example/IFoo.h>`).

## 4. Rust backend (`rust`, library `libbinder_rs`)

+ Supported since **Android 12**, for memory-safe system services, daemons, and HALs.

## Summary

| Backend | Language | Binder library | Typical use | Stable ABI |
| --- | --- | --- | --- | --- |
| `java` | Java / Kotlin | `android.os.Binder` | Apps, framework services | n/a |
| `cpp` | C++ | `libbinder` | Platform-internal native services (system partition) | No |
| `ndk` | C++ | `libbinder_ndk` | Vendor HALs, APEX, mainline modules, NDK apps | **Yes** |
| `rust` | Rust | `libbinder_rs` | Memory-safe system services / HALs | Yes (built on NDK) |

In `Android.bp`, backends are enabled per `aidl_interface`. The generated library names are
`<name>-V<n>-java`, `<name>-V<n>-cpp`, `<name>-V<n>-ndk`, and `<name>-V<n>-rust`.
For an `unstable: true` interface, there is no version suffix: `<name>-java`, `<name>-ndk`, and so on.

## Related notes

+ [AIDL_intro.md](AIDL_intro.md)
+ [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md), [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md): NDK backend examples
+ [AIDL_binding.md](AIDL_binding.md): Java/Kotlin example

## Reference

+ [AIDL backends](https://source.android.com/docs/core/architecture/aidl/aidl-backends)
