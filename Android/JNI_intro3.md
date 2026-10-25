# JNI on Android 14

On Android 14, integrating C/C++ code into a Kotlin-based app relies on the Android NDK (Native Development Kit), CMake, and JNI.  
Android Studio fully automates much of the toolchain configuration for modern projects targeting Android 14.

## How Kotlin Calls C++ on Android 14 (End-to-End Workflow)

### 1. Setup in Android Studio

When you create a project using the **"Native C++"** template in Android Studio,  
the IDE automatically configures:

+ The NDK & CMake: To compile your C++ files into native shared libraries (`.so` files).
+ Project Structure: A cpp/ folder containing your native code alongside your Kotlin source sets.

### 2. Declare the Native Method in Kotlin

In Kotlin, you use the external keyword to flag functions whose bodies are written in C++.  
You also load the shared library inside a companion object.

```kotlin
package com.example.myandroiapp

class NativeLib {
    companion object {
        // Loads "libnative-lib.so" when the class is referenced
        init {
            System.loadLibrary("native-lib")
        }
    }

    // Declaring an external native function
    external fun stringFromJNI(): String
}
```

### 3. Map to C++ using JNI Naming Rules

In your C++ source file (e.g., `native-lib.cpp`),  
you implement the function **using JNI's strict naming convention**  
so the Java Virtual Machine (Dalvik/ART on Android 14) can locate it:

> Java_PackageName_ClassName_MethodName

```c++
#include <jni.h>
#include <string>

// extern "C" prevents C++ compiler name-mangling
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_myandroiapp_NativeLib_stringFromJNI(JNIEnv *env, jobject thiz) {
    std::string hello = "Hello from C++ on Android 14!";
    
    // Use the JNIEnv pointer to create a Java/Kotlin-compatible String
    return env->NewStringUTF(hello.c_str());
}
```

### 4. Build Configuration via CMake

Android 14 uses CMake to define how C++ source files are compiled.  
Your `CMakeLists.txt` file links your source file to the native library name **expected by Kotlin**:

```ini
cmake_minimum_required(VERSION 3.22.1)
project("native-lib")

# Define a shared library named native-lib containing native-lib.cpp
add_library(
        native-lib
        SHARED
        native-lib.cpp
)

# Link Android system libraries if you need logging or graphics
target_link_libraries(
        native-lib
        android
        log
)
```

## Key Considerations for Android 14

1. 64-Bit Requirement (arm64-v8a, x86_64):  
   Android 14 strictly enforces 64-bit app execution requirements for most modern environments.  
   Ensure your CMake build configurations target modern ABIs (arm64-v8a for physical devices, x86_64 for the Android Studio Emulator).
2. ART (Android Runtime) & `JNIEnv`:  
   On Android 14, ART handles threads running native code via `JNIEnv`. Remember that JNIEnv *env is thread-local.  
   You cannot pass a JNIEnv pointer freely across different native threads  
   without detaching/attaching them to the JVM via the Java VM interface (JavaVM).
3. Performance Optimization:  
   Passing data frequently across the JNI boundary (marshaling strings, heavy arrays) introduces performance overhead.  
   For performance-critical code on Android 14 (such as real-time camera processing or audio filters),  
   minimize JNI calls by batching data processing entirely on the C++ side before returning a single result back to Kotlin.
