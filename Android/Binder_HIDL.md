# HIDL and Binder

HIDL (HAL Interface Definition Language) and Binder share a direct, foundational relationship:  
HIDL was created specifically to bring the power of Binder IPC down into Android's Hardware Abstraction Layer (HAL).

To understand how they work together, it helps to look at why HIDL was introduced and how it leverages the Binder driver.

## 1. The Context: Why HIDL Needed Binder

Before Android 8 (Oreo),  
communication between the Android Framework and hardware drivers (like cameras, sensors, and audio)  
often happened inside the same system process using traditional shared libraries, or via custom vendor sockets.  
This lack of process isolation meant that  
a bug or crash in a vendor's hardware driver could easily drag down the entire Android runtime and system server.

To fix this, Google introduced Project Treble, which strictly decoupled the Android OS Framework from vendor hardware implementations.  
To enforce this boundary, Android needed hardware components to run in their own isolated native processes  
and communicate safely across process lines.

Enter HIDL and Binder.

## 2. How HIDL Uses Binder (The "Binderized" HAL)

HIDL defines the interface syntax for **hardware services** using `.hal` files.  
When compiled, HIDL generates code that bridges high-level hardware requests into low-level transport mechanisms.

While HIDL supported a legacy "passthrough" mode (where the HAL ran as a shared library in the same process for transition purposes),  
its primary architectural mode was Binderized:

+ hwbinder (**Hardware Binder**): Regular Android app-to-service communication uses `/dev/binder`.  
  HIDL utilizes a dedicated variant of the binder driver and protocol called hwbinder (accessed via `/dev/hwbinder`),  
  managed by a specialized service manager called `hwservicemanager`.
+ Remote Procedure Calls (RPC): When the Android framework wants to talk to a **hardware component** (e.g., turning on the camera flash),  
  it doesn't call a local function.  
  Instead, it makes an RPC call through a HIDL-generated **proxy**,  
  which packages the request and pushes it through the hwbinder driver to the vendor's dedicated native daemon process.

## 3. Relationship Breakdown

### Feature of Binder (/dev/binder)

+ Domain: General system-wide IPC (Apps, System Services, Framework).
+ Role: The core kernel driver routing the data packets and managing process threads.
+ Service Manager: `servicemanager`

### Feature of HIDL (/dev/hwbinder)

+ Domain: Low-level hardware communication (Framework to HAL daemon processes).
+ Role: The interface definition language & compiler toolkit (hidl-gen) that defines how hardware methods map to those packets.
+ Service Manager: hwservicemanager

## 4. Current Status: The Shift Back to AIDL

While HIDL successfully isolated hardware using Binder-based mechanics for several years,  
maintaining 2 entirely separate interface languages (*AIDL for apps/services and HIDL for HALs*) created unnecessary fragmentation.

Starting with modern Android versions, **Google deprecated HIDL**.  
Android extended standard AIDL to natively support C++ and Rust,  
allowing the core Binder driver (`/dev/binder`) to handle hardware communication directly.  
Consequently, modern Android devices now use standard **AIDL** for hardware interfaces, phasing out hwbinder and HIDL entirely.
