# NDK introduction

**NDK stands for Native Development Kit.**  
It is a toolset provided by Google that  
allows you to implement parts of your Android app or system components **using native code languages, specifically C and C++**.

While the standard Android SDK uses Java or Kotlin running inside the Android Runtime (ART/JVM),  
the NDK lets you bypass the JVM and compile native machine code directly for the device's CPU architecture (e.g., ARM, x86).

## Why Do Developers Use the NDK?

1. Performance & Compute Intensity:  
   For heavy computing tasks like 3D rendering, video encoding/decoding, cryptography, physics simulations, or audio processing,  
   C/C++ offers raw speed that outperforms managed Java/Kotlin code.
2. Reusing Existing C/C++ Codebases:  
   If you have an established cross-platform library written in C or C++ (such as SQLite, OpenCV, or custom game engines),  
   the NDK allows you to bundle and run it directly inside Android.
3. Low-Level Hardware Access:  
   As seen in our pure C++ AIDL example, the NDK allows system developers and hardware vendors to build low-level daemons,  
   HALs (Hardware Abstraction Layers), and native system services  
   that communicate directly with the Linux kernel without needing Java wrappers.

## How the NDK Fits Into Android Architecture

+ **Android SDK** (Software Development Kit): Used for standard app development.  
  Uses Java/Kotlin, provides UI components (Activities, Views), and runs inside the managed JVM sandbox.
+ **Android NDK** (Native Development Kit): Used for native development.  
  Compiles directly into native binaries (`.so` shared libraries using clang/LLVM)  
  that are packaged inside your APK or system image.

[ Kotlin/ Java App ]  ──(Uses SDK)
        │
        v (Optional via JNI or Pure NDK Service)
[ C/ C++ Native Code ] ──(Compiled via NDK)
        │
        v
[ Linux Kernel / Hardware ]

## Key Components Provided by the NDK

When you download the NDK (usually via Android Studio's SDK Manager), it gives you:

+ Compilers & Toolchains:  
  GCC/Clang compilers configured to build binaries for Android's supported ABIs (armeabi-v7a, arm64-v8a, x86, x86_64).
+ Native Headers & Libraries: Standard C/C++ libraries, plus Android-specific system APIs  
  (like OpenGL ES for graphics, OpenSL ES/ AAudio for audio, logging via liblog, and Binder/AIDL NDK headers).
+ Build Integration: Works seamlessly with CMake or ndk-build to compile your native source code alongside your Android project.

## NDK and JNI

While people often mention them together, NDK and JNI solve 2 entirely different problems.  
Think of it this way:

+ NDK is the Workshop (The Tools): It gives you the equipment required **to build native C/C++ code for Android.**
+ JNI is the Doorway (The Bridge): It is the standard communication protocol that **lets Java/Kotlin code talk directly to C/C++ code.**

### Quick Comparison Table

#### Feature: NDK (Native Development Kit)

+ What is it: A toolset/ software package provided by Google.
+ What does it do: Provides compilers (Clang), linkers, build tools (CMake),  
  and header files so you can compile C/C++ for Android architectures.
+ When do you use it: Whenever you want to write or compile C/C++ code for an Android project.

#### Feature: JNI (Java Native Interface)

+ What is it: A programming standard/ interface specification.
+ What does it do: Defines how the Java Virtual Machine (JVM) calls native functions,  
  translates data types, and shares memory with C/C++.
+ When do you use it: Whenever Java or Kotlin code needs to directly invoke a C/C++ function within the same process.

### How They Work Together (And When They Don't)

You can actually use one without the other, which ties back to the concepts we discussed earlier:

1. Using NDK with JNI (Traditional Android App):  
   If you are writing a standard Android app in Kotlin and want to include a custom C++ library,  
   you use the **NDK** to compile that library into a `.so` file,  
   and you use **JNI** to let your Kotlin code call functions inside that `.so` file.
2. **Using NDK without JNI (Pure C++ AIDL Service)**:  
   In our native daemon example, you used the NDK backend for AIDL.  
   Because your daemon was written entirely in C++, it didn't use Java, the JVM, or Android Runtime (ART) at all.  
   Therefore, JNI was completely bypassed, but you still used the NDK toolchain to compile your C++ code.
