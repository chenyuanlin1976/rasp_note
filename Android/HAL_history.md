# Android HAL history

The history of the Android HAL is the story of separating **vendor hardware code** from the **Android framework**.
It went in 3 steps: in-process libraries, then HIDL (Project Treble), then stable AIDL.

## Summary

| Era | Android versions | Interface | Where the vendor code runs | Main problem solved / left |
| --- | --- | --- | --- | --- |
| `libhardware_legacy` | early 1.x | Ad-hoc C/C++ library APIs | Linked into the framework process | No standard module model |
| `libhardware` (`hw_get_module`) | 1.x – 7.x (still loadable later) | C structs (`hw_module_t`, `hw_device_t`) in `hardware/libhardware/include/hardware/*.h` | `dlopen()`'d **into** the framework process | Standard headers, but no stable ABI between framework and vendor |
| HIDL (Project Treble) | 8 – 10 (deprecated since 10) | `.hal` files, versioned packages (`@1.0`) | Separate vendor process (**binderized**, `/dev/hwbinder`), or in-process (**passthrough**) | Framework and vendor can be updated independently |
| Stable AIDL | 11+ | `.aidl` + `@VintfStability`, frozen versions | Separate vendor process over `/dev/binder` | One IPC language for apps, services, and HALs |

## 1. In-process libraries (`libhardware_legacy` and `libhardware`)

From the early open-source releases, 2 styles existed side by side.

### `libhardware_legacy`

+ Each subsystem (Wi-Fi, power, uevent, ...) had its own library and its own ad-hoc API.
+ Framework code called these functions directly, with no common module model.

### `libhardware` and `hw_get_module()`

+ A standard C header per HAL type (`lights.h`, `sensors.h`, `gralloc.h`, `camera.h`, `audio.h`, ...).
  Each header defines a `hw_module_t` and its `hw_device_t` function tables.
+ `hw_get_module(id, &module)` searches `/system/lib/hw/` and `/vendor/lib/hw/` for `<id>.<variant>.so` and `dlopen()`s it.
  + The variant comes from properties: `ro.hardware.<id>`, `ro.hardware`, `ro.product.board`, `ro.board.platform`, `ro.arch`.
  + If no variant matches, it falls back to `<id>.default.so` (for example `lights.default.so` or `gralloc.rk30board.so`).
+ The module is loaded **into the framework process** that uses it (`system_server`, `mediaserver`, `surfaceflinger`, ...).

Problems:

+ There was **no stable ABI**. Vendor `.so` files were built against a specific framework version,
  so each Android upgrade needed new vendor code from the SoC maker. That was a major cause of slow updates.
+ A bug in vendor code ran with the **privileges of the framework process**, and a crash took that process down.

## 2. Project Treble and HIDL (Android 8, 2017)

Project Treble split the system image into the **framework** (`/system`) and the **vendor implementation** (`/vendor`).
Between the 2, it put a versioned, checked interface.

+ **HIDL** (HAL Interface Definition Language) defines versioned packages, for example `android.hardware.light@2.0::ILight`.
+ **VINTF** (Vendor Interface Object): the device manifest lists the HALs that the vendor provides,
  and the compatibility matrices list what the framework needs. Both are checked at build time and on OTA.
+ **VNDK** limits which system libraries vendor code may link against.
+ 2 HAL modes:
  + **Binderized**: the HAL runs in its own vendor process, and the framework calls it over `/dev/hwbinder` (`hwservicemanager`).
    This is the default, and required for most HALs on devices launching with Android 8+.
  + **Passthrough**: a HIDL wrapper around an in-process `.so`.
    It was used to migrate old `libhardware` modules, and for same-process HALs (SP-HALs) such as the graphics mapper, for performance.

## 3. Stable AIDL (Android 11, 2020 →)

+ HIDL was **deprecated in Android 10**. **AIDL HALs** have been supported since **Android 11**.
+ AIDL already existed for apps *and* native system services (the C++ `cpp` backend).
  What it lacked for HALs was **stability**. Stable AIDL added:
  + frozen, versioned interfaces (`aidl_interface` with `versions`, API dumps checked by the build)
  + `@VintfStability`, plus the stable-ABI **NDK backend** (`libbinder_ndk`) for vendor code
  + `<hal format="aidl">` entries in the VINTF manifest
+ AIDL HALs register with the normal `servicemanager` (`/dev/binder`).
  Vendor-to-vendor services used `/dev/vndbinder` (Android 8–10). It is deprecated since Android 11;
  new vendor ↔ vendor interfaces use stable AIDL on `/dev/binder` too.
+ Google has been migrating core HALs (lights, power, vibrator, health, camera, audio, ...) to AIDL, and new HAL interfaces must be AIDL.
  Devices upgraded from older releases may still ship some HIDL HALs.
  A few performance-critical same-process HALs are still loaded in-process instead of over Binder.

See [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md) for a side-by-side comparison of HIDL and AIDL.

## Related notes

+ [HAL_intro.md](HAL_intro.md)
+ [HIDL_intro.md](HIDL_intro.md), [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md)
+ [VINTF_intro.md](VINTF_intro.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md)

## Reference

+ [HAL types (binderized, passthrough, same-process)](https://source.android.com/docs/core/architecture/hal-types)
+ [HAL overview](https://source.android.com/docs/core/architecture/hal)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
