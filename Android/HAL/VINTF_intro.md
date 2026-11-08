# VINTF (Vendor Interface Object)

VINTF is the mechanism that lets Android check whether a **framework** image (system, system_ext, product)
and a **vendor** image (vendor, odm) can work together.
It was introduced with Project Treble in Android 8.0. Each side describes itself in XML:

+ a **manifest** says what that side *provides*;
+ a **compatibility matrix** says what that side *requires* from the other side.

`libvintf` (the "VINTF object") collects these files plus runtime information (kernel version and config,
SELinux policy version, AVB version) and checks whether the two sides match.
That is what allows a framework-only update (OTA or GSI) on top of an unchanged vendor image.

## 1. Why VINTF exists

Before Treble, the framework and the vendor HALs were built together, and there was no machine-readable contract between them.
A new Android release meant rebuilding and re-validating the vendor code as well.

With Treble, the vendor code talks to the framework only through versioned interfaces (HIDL, and AIDL HALs since Android 11).
VINTF records *which* interfaces and versions each side offers and expects, so the build, OTA, and VTS can verify compatibility instead of assuming it.

## 2. Manifests and matrices

| File | Describes | Written by | On the device |
| --- | --- | --- | --- |
| **Device manifest** | HALs the vendor/odm side provides, SELinux policy version, target FCM version | SoC vendor / OEM | `/vendor/etc/vintf/manifest.xml`, fragments in `/vendor/etc/vintf/manifest/`, `/odm/etc/vintf/manifest.xml` |
| **Framework compatibility matrix (FCM)** | HALs, kernel versions and configs, SELinux and AVB versions that the framework requires | Google (one matrix per FCM version), plus device additions | `/system/etc/vintf/compatibility_matrix.<level>.xml`, `/system/etc/vintf/compatibility_matrix.device.xml` |
| **Framework manifest** | HALs and services the framework side provides to vendor code (for example `android.frameworks.*`, `android.hidl.manager`), VNDK version | Google + device (system_ext, product) | `/system/etc/vintf/manifest.xml`, plus the system_ext and product manifests |
| **Device compatibility matrix (DCM)** | What the vendor side requires from the framework | SoC vendor / OEM | `/vendor/etc/vintf/compatibility_matrix.xml` |

The 2 pairs that must match:

```text
device manifest      <-- checked against -->  framework compatibility matrix
(vendor provides)                             (framework requires)

framework manifest   <-- checked against -->  device compatibility matrix
(framework provides)                          (vendor requires)
```

Notes:

+ The kernel is **not** described in the device manifest on the device.
  `libvintf` reads the running kernel's version and `/proc/config.gz` and checks them against the `<kernel>` requirements in the FCM.
  The device manifest can declare the kernel FCM version with `<kernel target-level="...">`.
+ The legacy Android 8.0 locations (`/vendor/manifest.xml`, `/system/manifest.xml`, `/system/compatibility_matrix.xml`)
  are still read on old devices. Newer devices use `etc/vintf/`.
+ Manifest **fragments** are merged at runtime. In `Android.bp`, a HAL module brings its own fragment with
  `vintf_fragments: ["<file>.xml"]`, so the HAL is declared only when the module is installed (Android 10+).
  HALs packaged in a vendor APEX ship their fragments in the APEX's `etc/vintf/`.

## 3. FCM versions (target level)

The framework compatibility matrices are versioned by **FCM version** (also called FCM level).
A framework release ships the matrix of its own level plus the matrices of older levels it still supports.

| FCM level | Android release |
| --- | --- |
| 1 / 2 / 3 / 4 / 5 | 8.0 / 8.1 / 9 / 10 / 11 |
| 6 | 12 |
| 7 | 13 |
| 8 | 14 |
| 202404 | 15 (levels switched to a year-month format) |
| 202504 | 16 |

+ The device manifest declares its **target FCM version**: `<manifest version="1.0" type="device" target-level="8">`.
  The vendor image is checked against the matrix of that level.
+ A framework release supports only a limited range of target levels.
  A device whose target level is older than that range can't take the new framework release without a vendor update.
+ When a HAL version is deprecated at level N, a device that targets level N or later must provide the newer version, if it provides that HAL at all.

## 4. When the checks run

+ **Build time**: `assemble_vintf` generates the final XML files (it fills in values such as the SELinux version),
  and the build then checks the device manifest against the framework matrices (and the reverse pair).
  An unmatched HAL fails the build. Typically, the error says that a HAL in the manifest isn't in any compatibility matrix.
+ **OTA time**: the update checks the new framework's matrices against the device's manifest and runtime info.
  If they don't match, the update is rejected.
+ **Runtime**: `servicemanager` uses the merged device manifest.
  A service whose binder has **VINTF stability** (`@VintfStability`) can register only if its instance is declared in a VINTF manifest.
  Otherwise `addService` fails and `servicemanager` logs that the instance isn't in the VINTF manifest.
  Clients can ask `AServiceManager_isDeclared()` / `ServiceManager.isDeclared()` before they wait for an optional HAL.
+ **VTS**: the VINTF tests compare the manifests with what is actually registered on the device and check them against the matrices.

## 5. Declaring an AIDL HAL

Example: `vendor.example.hardware.myhal.IMyHalService/default`.
The full HAL (`.aidl`, `Android.bp`, service, `.rc`, SELinux) is in [AIDL_HAL_impl.md](AIDL_HAL_impl.md).

**Device manifest fragment**, installed by the service module with `vintf_fragments`:

```xml
<!-- vendor.example.hardware.myhal-service.xml -->
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>vendor.example.hardware.myhal</name>
        <version>1</version>
        <fqname>IMyHalService/default</fqname>
    </hal>
</manifest>
```

+ `<name>` is the AIDL **package**. `<fqname>` is `<Interface>/<instance>`.
  The longer form `<interface><name>IMyHalService</name><instance>default</instance></interface>` is equivalent.
+ The service must register exactly `vendor.example.hardware.myhal.IMyHalService/default`, that is `<package>.<Interface>/<instance>`.
  The same string goes into `service_contexts`.
+ AIDL HALs have no `<transport>` element and use a single integer `<version>`, the frozen `aidl_interface` version.
  HIDL HALs use `<transport>hwbinder</transport>` and `@<major>.<minor>` versions.

**Framework compatibility matrix entry**: every HAL in the device manifest must also appear in a framework matrix.
Google's matrices list only `android.hardware.*` HALs.
For a vendor HAL, add a device-specific matrix with `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` (installed as `compatibility_matrix.device.xml`):

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

```shell
# BoardConfig.mk / device.mk
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += device/example/myboard/framework_compatibility_matrix.xml
```

Checklist (names must agree everywhere):

| Place | Value |
| --- | --- |
| `.aidl` | `package vendor.example.hardware.myhal;` + `@VintfStability interface IMyHalService` |
| `aidl_interface` | `name: "vendor.example.hardware.myhal"`, `stability: "vintf"`, frozen version 1 |
| Manifest fragment | `<name>vendor.example.hardware.myhal</name>`, `<version>1</version>`, `IMyHalService/default` |
| Framework matrix | Same name, version, interface, instance |
| Service code | `AServiceManager_addService(..., "vendor.example.hardware.myhal.IMyHalService/default")` |
| `service_contexts` | `vendor.example.hardware.myhal.IMyHalService/default u:object_r:hal_myhal_service:s0` |

## 6. Do you need VINTF?

Every service with **VINTF stability** on `/dev/binder` needs a VINTF entry. That includes vendor ↔ vendor services,
because `/dev/vndbinder` is deprecated since Android 11. Code that doesn't offer a Binder service doesn't need one.

| Situation | Mechanism | VINTF entry? |
| --- | --- | --- |
| Framework, system app, or `system_server` calls a vendor HAL | Stable AIDL HAL on `/dev/binder` (`servicemanager`) | **Yes** (device manifest + framework matrix) |
| Vendor process calls another vendor process | Stable AIDL (NDK or Rust backend) on `/dev/binder` | **Yes**, like any HAL |
| The same, legacy | cpp-backend AIDL on `/dev/vndbinder` (`vndservicemanager`), deprecated since Android 11 (opt-in) | No |
| A vendor daemon uses hardware only for itself (for example libgpiod in that daemon) | No IPC | No |
| Bring-up or debugging from `adb shell` (userdebug) | Command-line tools | No |
| 3rd-party app needs the hardware | A system app with a bound service in front of the HAL; the HAL itself is declared in VINTF | Yes, for the HAL |

+ Apps can't reach `vndservicemanager`, and SELinux `neverallow` rules stop app domains (and other core domains)
  from using vendor device nodes, sockets, or vendor properties.
  So "skip the HAL and let the app talk to a vendor daemon directly" doesn't work in a product.
+ For GPIO, the decision and the full examples are in [HAL_libgpiod.md](HAL_libgpiod.md#2-do-i-need-jni-native-aidl-hal-vs-jni)
  and [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md).
  Use the character device with libgpiod, not the deprecated `/sys/class/gpio`.

## 7. Inspect VINTF on a device

```shell
# merged inputs, by partition
adb shell ls /vendor/etc/vintf/ /vendor/etc/vintf/manifest/ /odm/etc/vintf/ /system/etc/vintf/
adb shell cat /vendor/etc/vintf/manifest.xml

# target FCM version of the device
adb shell grep target-level /vendor/etc/vintf/manifest.xml

# is the AIDL HAL registered?
adb shell service check vendor.example.hardware.myhal.IMyHalService/default
adb shell dumpsys -l | grep myhal

# registration rejected by servicemanager?
adb logcat -b all | grep -i -E "servicemanager|vintf"
```

`lshal` lists HIDL HALs (`hwservicemanager` and passthrough). For AIDL HALs, use `service` / `dumpsys`.

## Related notes

+ [HAL_history.md](HAL_history.md): libhardware → HIDL/Treble → stable AIDL
+ [AIDL_HAL_intro.md](AIDL_HAL_intro.md): AIDL as the HAL contract
+ [AIDL_HAL_impl.md](AIDL_HAL_impl.md): complete vendor AIDL HAL including VINTF and SELinux
+ [AIDL_HIDL_cmp.md](AIDL_HIDL_cmp.md), [HIDL_intro.md](HIDL_intro.md)
+ [HAL_libgpiod.md](HAL_libgpiod.md), [AIDL_HAL_gpio.md](AIDL_HAL_gpio.md), [../IPC/AIDL_app_3rdParty_access.md](../IPC/AIDL_app_3rdParty_access.md)
+ [../SELinux/neverallow_error.md](../SELinux/neverallow_error.md)

## Reference

+ [Vendor interface object](https://source.android.com/docs/core/architecture/vintf)
+ [Manifests](https://source.android.com/docs/core/architecture/vintf/objects)
+ [Compatibility matrixes](https://source.android.com/docs/core/architecture/vintf/comp-matrices)
+ [Matching rules](https://source.android.com/docs/core/architecture/vintf/match-rules)
+ [FCM lifecycle](https://source.android.com/docs/core/architecture/vintf/fcm)
+ [Device manifest development](https://source.android.com/docs/core/architecture/vintf/dm)
+ [VINTF tools (assemble_vintf, lshal)](https://source.android.com/docs/core/architecture/vintf/resources)
+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
