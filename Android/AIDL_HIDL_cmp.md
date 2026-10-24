# compare HIDL and AIDL

The relationship between HIDL and AIDL is an evolutionary one:  
**AIDL is the modern successor to HIDL**, designed to unify all Android IPC under a single, streamlined interface language.

While both serve the same fundamental purpose:  
**defining interfaces and generating the boilerplate code needed to communicate across process boundaries,**  
they were built for different layers of the operating system and different eras of Android architecture.

## 1. High-Level Comparison

### Feature: HIDL (HAL Interface Definition Language)

+ Primary Domain: Hardware Abstraction Layer (**HAL**) and vendor daemons.
+ Transport Layer: Hardware Binder (`/dev/hwbinder`).
+ Active Status: Deprecated (phased out starting around Android 11/12).
+ Supported Languages: C++, Java (limited legacy passthrough).

### Feature: AIDL (Android Interface Definition Language)

+ Primary Domain: **App-to-app, app-to-system service, and now modern HAL interfaces.**
+ **Transport Layer: Standard Binder (`/dev/binder`).**
+ Active Status: Current & Universal (used across the entire OS stack).
+ Supported Languages: Java, Kotlin, C++, and Rust.

## 2. Why HIDL Existed (The Predecessor)

When Google introduced Project Treble in Android 8  
**to separate the Android OS framework from vendor hardware**,  
they needed a way for system processes to talk to hardware vendor processes securely via **IPC**.

+ They couldn't use traditional AIDL at the time  
  because standard AIDL was heavily tied to Java/runtime environments, whereas **low-level vendor code needed pure C++.**
+ To solve this, Google created HIDL alongside a separate hardware-dedicated binder driver (`/dev/hwbinder`).

## 3. The Problem with Fragmenting the Ecosystem

Having 2 entirely separate interface languages created significant maintenance overhead:

+ Tooling Split: Developers had to learn AIDL for writing apps and system services,  
  but switch to HIDL (and .hal syntax) when writing hardware drivers.
+ Feature Disparity: AIDL supported rich language features, versioning, and modern types that HIDL lacked or handled differently.
+ Duplicate Runtimes: The system had to maintain 2 parallel binder infrastructures (`/dev/binder` and `/dev/hwbinder`)  
  and 2 service managers (`servicemanager` and `hwservicemanager`).

## 4. The Transition: How AIDL Replaced HIDL

As Android evolved, Google decided to bring hardware communication back under the standard Binder umbrella.  
To make this possible, AIDL was heavily upgraded:

+ C++ and Rust Support:  
  **AIDL gained native backends for C++ and Rust**, eliminating the need for a separate language (HIDL) to write low-level system code.
+ Stable AIDL: AIDL was updated to support stable, versioned interfaces (**stable aidl**),  
  making it safe for vendors to update hardware components independently without breaking the system framework.

Because standard AIDL can now do everything HIDL used to do  
plus more, with better performance and unified tooling,  
HIDL has been officially deprecated.

## Summary of the Evolution

+ HIDL was a transitional bridge used to bring Binder-based IPC down to the hardware layer during Project Treble.
+ AIDL is the ultimate destination: a single, universal interface language  
  **that now handles everything from a Kotlin app talking to a system service**,  
  all the way down to C++/Rust code interacting directly with hardware chips via **the core Binder driver**.
