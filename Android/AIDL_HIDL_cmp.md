# Compare HIDL and AIDL

**AIDL is the successor to HIDL.** Android now uses one interface language for every IPC boundary,
from apps all the way down to HALs.
Both languages do the same basic job: they define interfaces and generate the code that crosses process boundaries.
They were built for different layers and different eras of Android.

## 1. High-level comparison

| | HIDL (HAL Interface Definition Language) | AIDL (Android Interface Definition Language) |
| --- | --- | --- |
| Introduced | Android 8 (Project Treble) | Android 1.0; HAL support (stable AIDL) since **Android 11** |
| Domain | HALs only (framework ↔ vendor) | Apps, system services, **and HALs** |
| Transport | `/dev/hwbinder` + `hwservicemanager` | `/dev/binder` + `servicemanager` (and `/dev/vndbinder` + `vndservicemanager` for vendor ↔ vendor) |
| File syntax | `.hal`, versioned packages `@1.0` | `.aidl`, versioned with `aidl_interface` `versions` |
| Languages | C++, Java (binderized HALs only) | Java/Kotlin, C++ (`cpp`, `ndk`), Rust |
| Status | **Deprecated since Android 10**; no new HIDL HALs | Current standard |

## 2. Why HIDL existed

Project Treble (Android 8) split the OS framework from vendor code, so the two sides needed a **stable, versioned** IPC contract.

+ AIDL already had a C++ backend, but it had **no stability guarantees**.
  Interfaces weren't versioned or frozen, and `libbinder` had no stable ABI.
  So a framework update could break a vendor HAL built against an older interface.
+ HIDL fixed this with strictly versioned packages (`android.hardware.foo@1.0`)
  and a separate binder domain (`/dev/hwbinder`) for framework ↔ vendor traffic.

## 3. Problems of having two languages

+ **Tooling split**: AIDL for apps and services, HIDL (`.hal`) for hardware.
+ **Feature disparity**: each language had features and types the other did not.
+ **Duplicate runtimes**: 2 binder domains and 2 service managers (`servicemanager` and `hwservicemanager`).

## 4. How AIDL replaced HIDL

+ **Stable AIDL** (Android 10/11): `aidl_interface` with frozen `versions`, API dump checks, and `@VintfStability`,
  so an interface can safely cross the system/vendor boundary.
+ **NDK backend** (`libbinder_ndk`): a stable C ABI that vendor code can link against.
+ **Rust backend** (Android 12).
+ AIDL HALs are declared in the VINTF manifest with `format="aidl"`, and are registered with the normal `servicemanager`.

Because stable AIDL covers everything HIDL did, HIDL is deprecated, and new HAL interfaces are written in AIDL.

## 5. Summary

+ HIDL was the Treble-era bridge that brought versioned Binder IPC to the HAL layer.
+ AIDL is now the single interface language, from a Kotlin app calling a system service
  down to a C++/Rust HAL that talks to hardware.

## Related notes

+ [HIDL_intro.md](HIDL_intro.md), [Binder_HIDL.md](Binder_HIDL.md)
+ [AIDL_HAL.md](AIDL_HAL.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md)

## Reference

+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [HIDL (deprecated)](https://source.android.com/docs/core/architecture/hidl)
