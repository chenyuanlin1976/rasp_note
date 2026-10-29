# The HAL history

The history of the Android Hardware Abstraction Layer (HAL) tracks Android's evolution  
from a fragmented open-source project into a modular, enterprise-grade operating system.

## 1. The Legacy Era: libhardware_legacy (2008–2009)

In early Android versions (Android 1.0 to 1.5), the HAL was modeled using `libhardware_legacy`.

+ Design: It closely mirrored traditional embedded Linux software architecture.  
  Hardware modules were loaded as shared libraries (.so),  
  and **system services** interacted with them via **direct** function calls.
+ The Problem: The design was tightly coupled.  
  Because vendors directly integrated their proprietary driver code and shared libraries into the core system image,  
  updating the Android OS framework meant rewriting or recompiling large portions of vendor-specific code.  
  This created massive OS fragmentation and delayed software updates.

## 2. The Standardization Era: libhardware & hw_get_module (2009–2017)

To reduce tight coupling, Android introduced `libhardware` (anchored around `hw_get_module`) starting around Android 2.0.

+ Design: It introduced standard C header files (e.g., lights.h, sensors.h) defining clean function structures,  
  and used a dynamic loading mechanism via `dlopen()` to discover modules at runtime (`<module>.default.so`).
+ The Problem: While it cleanly separated interface headers from implementations,  
  code was still dynamically loaded directly into the memory space of system processes.  
  Vendors still had to tightly couple their code to specific versions of the Android system framework,  
  meaning ecosystem fragmentation persisted.

## 3. The Modularization Era: Project Treble & HIDL (2017–2020)

Introduced with Android 8 (Oreo), Project Treble fundamentally restructured Android  
by separating the Android OS framework from the vendor-specific hardware implementation.

+ Design: Google introduced HIDL (HAL Interface Definition Language).
  Instead of loading shared libraries locally into system memory,  
  hardware components were pushed into isolated, dedicated daemon processes residing in the vendor partition.
+ **IPC via Binder**: Communication between the system framework and the vendor HAL shifted  
  from direct function calls to **Android Binder IPC** (Binderized HALs).  
  This allowed Google to update the Android framework independently of vendor silicon drivers.  

## 4. The Modern Era: Stable AIDL (2020–Present)

Beginning with Android 11 and 12, Google shifted away from HIDL in favor of **Stable AIDL** (Android Interface Definition Language).

+ Design: Android unified its IPC language.  
  AIDL, which was historically used exclusively for **app-to-service** communication,  
  **was extended to natively support low-level native/C++/Rust HAL interfaces**.
+ Current State: AIDL provides better type safety, cleaner versioning, backward compatibility, and unified tooling.  
  HIDL has been officially deprecated, and all modern hardware components in Android rely on stable, **binderized AIDL services**.
