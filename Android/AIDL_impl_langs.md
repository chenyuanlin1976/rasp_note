# AIDL implement languages

The Android Interface Definition Language (AIDL) is a tool used in Android  
to define the programming interface that  
**a client and service agree upon to communicate via Inter-Process Communication (IPC)**.

When you define an interface in an `.aidl` file,  
the AIDL compiler generates **stub code** that handles the underlying marshalling and binder transactions.  
Android supports 4 primary backend languages to implement and consume AIDL interfaces:

## 1. Java

+ Overview: The traditional and most widely used language for Android application development.
+ Usage: Commonly used for standard Android apps, framework APIs, and services.  
  The AIDL compiler automatically generates `.java` interface and **stub** files during the build process.
+ Developers: App and framework developers.

## 2. Kotlin

+ Overview: Fully interoperable with Java and modern Android's preferred language.
+ Usage: While AIDL itself is written in a syntax loosely based on Java,  
  Kotlin projects consume the generated Java stub classes seamlessly.  
  You implement the generated **Stub** class and its methods using idiomatic **Kotlin** syntax  
  (such as object expressions or lambdas).
+ Developers: Modern Android app developers.

## 3. C++

+ Overview: Used for native Android development, system services, and **Hardware Abstraction Layers (HALs)**.
+ C++ Backends: AIDL provides 2 ways to write C++ implementations:
  + NDK Backend (`libbinder_ndk`): Highly recommended for stable, unbundled system components and vendor modules. It uses the Native Development Kit.
  + CPP Backend (`libbinder`): Older/internal framework backend, primarily used deep within the Android platform runtime system.
+ Developers: Platform, system, and game developers working with native code (NDK).

## 4. Rust

+ Overview: Supported in modern versions of Android (especially starting with Android 13/AOSP developments) for writing memory-safe system components.
+ Usage: The AIDL compiler generates Rust-idiomatic code (`libbinder_rs`) allowing developers to implement system services,  
  daemon processes, and low-level modules entirely in Rust.
+ Developers: Platform and system-level developers.

## Summary Table

| Backend/ Language | Typical Use Case                      | Target Developer           |
| ----------------- | ------------------------------------- | -------------------------- |
| Java              | Standard Android Apps & Framework     | App & Framework Developers |
| Kotlin            | Modern Android Apps                   | App Developers             |
| C++ (NDK/CPP)     | HALs, Performance-critical NDK apps   | System & NDK Developers    |
| Rust              | Memory-safe system services & daemons | Platform Developers        |
