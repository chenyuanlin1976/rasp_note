# JNI: to communicate with C++ code

Here is a clear, structured guide to understanding JNI (Java Native Interface)  
and how it enables Kotlin (or Java) to communicate with C++ code.

## 1. What is JNI?

JNI is a standard programming framework that  
**allows Java/Kotlin code running inside a JVM to interact with applications and libraries written in native languages like C, C++, or assembly**.

Since Kotlin runs on the Java Virtual Machine (JVM),  
it shares the same underlying interoperability mechanism as Java.  
**JNI acts as a bridge**, translating data types and method calls between the managed JVM world and the unmanaged native world.

## 2. Why Use JNI with Kotlin/C++?

+ Performance: Running heavy computations, image/video processing, physics engines, or cryptographic algorithms in C/C++ is much faster.
+ Code Reuse: Integrating existing C/C++ libraries (like OpenCV, SQLite, or custom SDKs) without rewriting them in Kotlin.
+ Hardware Access: Directly interacting with device sensors, low-level system APIs, or hardware components (common in Android NDK development).

## 3. How Kotlin Calls C++ (Step-by-Step)

The process relies on a few key components: external functions, Shared Libraries (`.so`/ `.dll`/ `.dylib`),  
and **JNI Function Name Mangling**.

### Step 1: Declare the Native Function in Kotlin

In Kotlin, you use the external modifier to tell the compiler that the function's body is implemented in native code.  
You also need to load the compiled native library using `System.loadLibrary()`.

```kotlin
package com.example.app

class NativeBridge {
    companion5 object {
        // Load the shared library (e.g., libnative-lib.so on Android/Linux)
        init {
            System.loadLibrary("native-lib")
        }
    }

    // Declare a native function
    external fun stringFromJNI(): String
    
    // Pass data from Kotlin to C++
    external fun addNumbers(a: Int, b: Int): Int
}
```

### Step 2: Implement the C++ Function

In C++, you write the function using a **specific naming convention expected by JNI**,  
or by registering the native methods dynamically.  
Using the standard naming convention, the function name looks like this:

`Java_<PackageName>_<ClassName>_<MethodName>`

If your Kotlin class is in the package `com.example.app`  
and named NativeBridge, the C++ function signature looks like this:

```c++
#include <jni.h>
#include <string>

// Extern "C" prevents C++ name mangling so the JVM can find the symbols
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_app_NativeBridge_stringFromJNI(JNIEnv *env, jobject thiz) {
    std::string hello = "Hello from C++!";
    // Convert C++ string to Java/Kotlin String using JNI environment pointer
    return env->NewStringUTF(hello.c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_app_NativeBridge_addNumbers(JNIEnv *env, jobject thiz, jint a, jint b) {
    return a + b;
}
```

### Step 3: Type Mapping (Bridging Data Types)

Kotlin and C++ have different data types in memory.  
JNI provides equivalent mappings so data can be safely passed back and forth:

| Kotlin/ Java Type | JNI Native Type | C++ Type                                  |
| ----------------- | --------------- | ----------------------------------------- |
| Int               | jint            | int32_t                                   |
| Long              | jlong           | int64_t                                   |
| Boolean           | jboolean        | uint8_t                                   |
| String            | jstring         | jstring (requires helper methods to read) |
| ByteArray         | jbyteArray      | jbyteArray (requires pointer pinning)     |

## 4. Understanding JNIEnv and jobject

Every JNI function in C++ receives 2 essential parameters:

1. `JNIEnv *env`: A pointer to the JNI interface table.  
   It provides almost all the functions you need to interact with Kotlin/Java objects  
   (creating strings, throwing exceptions, reading object fields, calling methods).
2. `jobject thiz`: A reference to the current object instance (this) of the Kotlin class that called the native method.  
   (If it's a static native method, it becomes a jclass reference to the class itself).

## 5. Modern Alternative: Kotlin Multiplatform (JNA / JNI via Gradle)

While raw JNI is powerful, writing manual JNI boilerplate can be tedious and prone to segmentation faults if memory is mishandled.

+ In Android Studio, tools like CMake and the NDK automate the compilation of C++ into `.so` libraries.
+ For cleaner desktop or server-side Kotlin/Java interoperability,  
  developers often use JNA (Java Native Access) or Project Panama,  
  which allow calling native C libraries directly from Kotlin annotations without writing any C++ JNI bridge code.
