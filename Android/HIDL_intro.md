# HIDL introduction

HIDL stands for **HAL Interface Definition Language** (pronounced hide-l).  
It was introduced by Google in Android 8 (Oreo) as part of Project Treble  
*to decouple the Android OS framework from the low-level vendor hardware implementations*  
(HAL - Hardware Abstraction Layer).

## Why Was HIDL Created?

Before Project Treble and HIDL,  
the Android framework and vendor-specific HAL code were tightly coupled inside the same system image (system.img).  
If a chip vendor (like Qualcomm or MediaTek) wanted to update a device to a new Android version,  
they had to rewrite and re-test vast portions of low-level driver code.

HIDL allowed hardware interfaces to be cleanly specified in **.hal** files.  
This meant Google could update the Android framework independently,  
and vendors could update their hardware drivers separately without breaking compatibility.

## How HIDL Works

1. Interface Definition (.hal): Similar to AIDL, you write a descriptive interface file.  
   However, HIDL uses a C++-like syntax rather than Java syntax.
2. Code Generation (hidl-gen): The build system runs the hidl-gen tool to generate C++  
   (and sometimes Java) boilerplate files (proxies and stubs).
3. Communication Modes: HIDL supports two modes of communication between the Android framework and the hardware:
   + Binderized Mode: Uses Android’s standard Binder IPC driver to pass data across separate processes  
     (client and server run in different processes).
   + Passthrough Mode: The HAL is compiled into a shared library and loaded directly into the client process  
     (acting essentially as a direct function call, used primarily during early transition phases for older devices).

### Example of a HIDL Interface (.hal)

```java
package android.hardware.samples.example@1.0;

interface IExample {
    getScore() generates (int32_t score);
    updateScore(int32_t newScore);
};
```

## Current Status: HIDL is Deprecated

While HIDL was a major architectural milestone for Android, it has been deprecated.

+ Deprecation Timeline: Google deprecated HIDL starting in Android 10,  
  and newer Android versions have blocked the addition of new HIDL interfaces entirely.
+ The Successor (**Stable AIDL**): Android has unified its IPC architecture onto Stable AIDL.  
  Modern Android versions use AIDL not just for App-to-Service communication,  
  but also for low-level native HAL implementations.

## Why did Google move away from HIDL?

+ Tooling Fragmentation: Maintaining a separate language (.hal) and a separate compiler (hidl-gen) alongside AIDL created unnecessary duplication.
+ Feature Limitations: HIDL lacked robust support for advanced features like native asynchronous callbacks, complex data structuring,  
  and easy versioning compared to what Stable AIDL eventually grew to support.
+ Unified Ecosystem: Using Stable AIDL everywhere means developers and system architects only need to master a single interface definition language  
  for both high-level app interactions and low-level hardware drivers.
