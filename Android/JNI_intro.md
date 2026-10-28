# JNI introduction

**JNI stands for Java Native Interface.**  
It is a standard programming framework that  
allows Java or Kotlin code running inside a Java Virtual Machine (JVM) to interact with applications and libraries  
**written in native languages like C and C++**.

In the context of Android development (especially low-level features like controlling LEDs via `sysfs`),  
JNI is the bridge that lets your high-level Android app or system service **talk directly to hardware or operating system drivers.**

## Why Do We Use JNI

1. Hardware & OS Access: Android apps run inside a secure sandbox (ART/JVM)  
   and **cannot** directly access low-level Linux kernel components like `/sys/class/leds/`.  
   JNI allows your Java/Kotlin code to call C/C++ code that has **the necessary system privileges.**
2. Performance: For intensive tasks (like image processing, cryptography, or real-time rendering),  
   C/C++ runs significantly faster than managed Java/Kotlin code.
3. Reusing Existing Libraries: It allows Android to use massive open-source C/C++ libraries  
   (like OpenCV, FFmpeg, or custom hardware abstraction layers / HALs).

## How JNI Works (The Architecture Flow)

[ Kotlin/ Java Code ]
       │  (Calls an `external` function)
       v
[ JNI Bridge Layer ]
       │  (Translates JVM data types to C/C++ types)
       v
[ C/ C++ Native Code (`.so`) ]
       │  (Interacts with Kernel, Hardware, Files, etc.)
       v
[ Linux Kernel/ Hardware ]

## A Simple Code Example

Here is a quick look at how JNI connects Kotlin to C++.

### 1. The Kotlin Side

You declare a method with the external keyword and load your native library:

```kotlin
class NativeLedController {
    companion0 {
        // Loads libled_native.so when the class is initialized
        init {
            System.loadLibrary("led_native")
        }
    }

    // Declared as external (meaning the implementation is in C/C++)
    external fun nativeSetLedState(state: Int, delayOn: Int, delayOff: Int)
}
```

### 2. The C++ Side

In your C++ code, you write a function with a **specific naming convention**  
> Java_PackageName_ClassName_MethodName
so the JVM knows how to map it:

```c++
#include <jni.h>
#include <string>
#include <fstream>

// The function signature maps directly to NativeLedController.nativeSetLedState()
extern "C" JNIEXPORT void JNICALL
Java_com_example_led_NativeLedController_nativeSetLedState(
    JNIEnv* env,          // JNI interface pointer
    jobject /* this */,   // Reference to the Kotlin object instance
    jint state, 
    jint delayOn, 
    jint delayOff) 
{
    // C++ code can now safely write to the Linux sysfs node
    if (state == 1) {
        std::ofstream("/sys/class/leds/sys_led_r/brightness") << "255";
    } else {
        std::ofstream("/sys/class/leds/sys_led_r/brightness") << "0";
    }
}
```

## Key Things to Keep in Mind

+ Debugging Complexity: Debugging C/C++ code through JNI requires native debuggers (like LLDB in Android Studio)  
  and is generally harder than debugging pure Kotlin.
+ Memory Management: Unlike Java/Kotlin, C/C++ does not have an automatic Garbage Collector for everything.  
  If you allocate memory in C++ using `malloc` or `new`, you must manually free it, or you will cause memory leaks.
+ Security & Stability: A crash in your Java/Kotlin code usually throws an exception,  
  but a crash in your native C++ code (like a segmentation fault) will instantly crash the entire process (causing an app or system crash).

## JNI and AIDL

Strictly speaking,  
JNI and AIDL are 2 completely different technologies that solve different problems,  
but they work hand-in-hand in Android system architecture.

They do not directly call each other, but they are frequently used together in the same feature  
(like controlling hardware from an app).

### How They Differ

+ **AIDL** (Android Interface Definition Language): Used for IPC (Inter-Process Communication).  
  **It allows code in Process A (e.g., your Kotlin application) to talk to Process B**  
  (e.g., a system service or background daemon) across process boundaries using **Android's Binder driver.**
+ **JNI**: Used for language translation/bridging.  
  **It allows managed code (Java/Kotlin) inside the JVM to talk directly to native code (C/C++) running within the exact same process.**

### How They Work Together (The Blueprint)

When you want to control hardware (like an LED) from an Android app, AIDL and JNI form a relay chain.  
AIDL handles crossing the process boundary,  
and JNI handles dropping down into native C/C++ to touch the system files or hardware.

[ Kotlin App Process ]
       │
       │  1. Calls AIDL interface method over Binder IPC
       v
[ System Service/ Daemon Process ]
       │  (Implements the AIDL Stub)
       │  2. Calls a native method via JNI
       v
[ C/C++ Native Layer ]
       │  (Implements the JNI function)
       │  3. Writes to Linux sysfs
       v
[ Linux Kernel / Hardware (`/sys/class/leds/`) ]

### Alternative: Pure C++ AIDL (Without JNI)

**Modern Android (AOSP) supports a C++ backend for AIDL** (aidl-cpp or the NDK backend).

If your system daemon is **written entirely in C++** (rather than Java/Kotlin), it can implement the AIDL server **stub** natively in C++.  
In this specific architecture, *JNI is bypassed entirely* because your native daemon receives the Binder/AIDL call directly in C++,  
and can write to the sysfs node without ever touching Java or JNI.
