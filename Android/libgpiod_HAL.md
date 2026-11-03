# libgpiod and HAL: do I need JNI?

Suppose you control GPIOs with **libgpiod** on an AOSP device. Do you need **JNI**?
Usually **no**. Use a native AIDL HAL service and Binder.
JNI is only an *in-process* bridge, and on Treble devices the in-process design can't reach vendor hardware anyway.

First, the layers:

+ **Kernel**: the GPIO driver (gpiolib) exposes `/dev/gpiochipN`.
  The kernel does **not** use libgpiod.
+ **libgpiod**: a **user-space** C library that wraps the `/dev/gpiochipN` ioctls.
  Whatever process links it must be allowed to open the device node.
+ **JNI**: lets Java code call a native library **loaded into the same process**.
+ **AIDL / Binder**: lets code in one process call code in **another** process. The proxy/stub code is generated, so you write no JNI.

## 1. Native AIDL HAL service (recommended, no JNI)

```text
Java/Kotlin (system app / framework)  --Binder (generated Java proxy)-->  C++ HAL service --libgpiod--> /dev/gpiochipN
```

+ A C++ (or Rust) daemon in `/vendor/bin/hw/` links libgpiod and owns the GPIO lines.
+ It exposes a **stable AIDL** interface (`@VintfStability`, NDK backend).
+ Java clients use the **Java code generated** from the same `.aidl` file. Neither side has JNI code.
+ Only the HAL's SELinux domain gets access to `/dev/gpiochip*`.
  Clients only get permission to *call the HAL* (`hal_client_domain`).

Full example: [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md).

## 2. JNI wrapper in a Java process (legacy, usually not possible today)

```text
Java class --JNI--> libmygpio_jni.so --libgpiod--> /dev/gpiochipN     (all inside ONE process)
```

1. A native library wraps the libgpiod calls.
2. A JNI layer (`RegisterNatives` / `System.loadLibrary`) exposes them to a Java class.
3. Java code calls that class.

The catch: because everything runs **in the calling process**, *that* process must be able to open `/dev/gpiochipN`.

+ **In an app**: `untrusted_app` (and normal system apps) can't access device nodes.
  SELinux `neverallow` rules block it, so CTS fails if you add such rules.
+ **In `system_server`** (a JNI-backed framework service, the pre-Treble HAL style):
  Treble `neverallow` rules stop core system domains from accessing vendor-specific device nodes.
  The vendor code would also become part of the system image again.

So on Android 8+ devices, the JNI design only fits rare platform-internal cases where the hardware access is part of the system image.
For vendor hardware such as GPIO, use option 1.

JNI is still the right tool when an app needs a native library **for computation** (codecs, math, a game engine)
and doesn't need privileged hardware access.
See [JNI_intro.md](JNI_intro.md) and [NDK_intro.md](NDK_intro.md).

## 3. Binder domains (where "vendor binder" fits)

| Device | Service manager | Used between |
| --- | --- | --- |
| `/dev/binder` | `servicemanager` | apps ↔ framework, and **framework ↔ AIDL HALs** |
| `/dev/vndbinder` | `vndservicemanager` | vendor process ↔ vendor process only |
| `/dev/hwbinder` | `hwservicemanager` | framework ↔ HIDL HALs (legacy) |

A GPIO HAL that a system app or framework service calls registers over `/dev/binder`,
with the NDK backend and a stable AIDL interface.
It does **not** use `vndbinder`; vndbinder is only for vendor ↔ vendor calls.

## Summary

| Goal | Use |
| --- | --- |
| Framework or system app controls vendor GPIO | **Native AIDL HAL service** (option 1); no JNI |
| Vendor daemon controls GPIO only for itself | Link libgpiod directly in that daemon; no IPC needed |
| 3rd-party app controls GPIO | A system app with a bound service in front of the HAL: [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md) |
| App needs native code for computation, no hardware | JNI / NDK |

## Related notes

+ [HAL_libgpiod.md](HAL_libgpiod.md): sysfs vs character device, libgpiod v1/v2, AOSP checklist
+ [AIDL_impl_gpio_cxx.md](AIDL_impl_gpio_cxx.md), [AIDL_HAL_impl.md](AIDL_HAL_impl.md)
+ [libgpiod_intro.md](libgpiod_intro.md), [libgpiod_intro2.md](libgpiod_intro2.md)

## Reference

+ [AIDL for HALs](https://source.android.com/docs/core/architecture/aidl/aidl-hals)
+ [Using binder IPC (binder domains)](https://source.android.com/docs/core/architecture/hidl/binder-ipc)
