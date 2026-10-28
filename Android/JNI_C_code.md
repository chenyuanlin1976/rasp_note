# JNI anc c code

To call C code from an Android app (typically written in Kotlin or Java) to control hardware like GPIO,  
you use the **Java Native Interface (JNI)** and the Android NDK (Native Development Kit).

## Step 1: Write the C Code with JNI Bindings

You write a C function that follows **JNI naming conventions** so the Java/Kotlin runtime can locate and call it.  
Inside your C file (e.g., `gpio_control.c`), you include **`<jni.h>`** and implement the function:

```c
#include <jni.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

// Example JNI function to set a GPIO pin state
JNIEXPORT jint JNICALL
Java_com_example_gpioapp_MainActivity_nativeSetGpioState(JNIEnv *env, jobject thiz, jint pin, jint state) {
    // In Linux/Android, you typically write to /sys/class/gpio/gpioX/value
    // (Or use character devices /dev/gpiochipX depending on the kernel version)
    
    char path[64];
    sprintf(path, "/sys/class/gpio/gpio%d/value", pin);
    
    int fd = open(path, O_WRONLY);
    if (fd < -1) {
        return -1; // Error opening GPIO
    }
    
    if (state == 1) {
        write(fd, "1", 1);
    } else {
        write(fd, "0", 1);
    }
    
    close(fd);
    return 0; // Success
}
```

## Step 2: Declare the Native Method in Kotlin/Java

In your Android app, declare the method using the **external** keyword (in Kotlin)  
and **load your compiled C library** in a `companion` object.

```kotlin
class MainActivity : AppCompatActivity() {

    companion object {
        // Load the compiled shared library (.so file)
        init {
            System.loadLibrary("gpio_control")
        }
    }

    // Declare the native method matching the C function signature
    external fun nativeSetGpioState(pin: Int, state: Int): Int

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Call the C method to set GPIO pin 17 to HIGH (1)
        val result = nativeSetGpioState(17, 1)
    }
}
```

## Step 3: Build with Android NDK and CMake

Android Studio uses CMake to compile C/C++ code into a shared library (`.so`).

### 1. Create a `CMakeLists.txt` file in your app's cpp directory

```ini
cmake_minimum_required(VERSION 3.18.1)
project("gpio_control")

add_library(
        gpio_control
        SHARED
        gpio_control.c
)

find_library(
        log-lib
        log
)

target_link_libraries(
        gpio_control
        ${log-lib}
)
```

### 2. Configure your build.gradle (Module-level) to point to the CMake file

```groovy
android {
    ...
    defaultConfig {
        ...
        externalNativeBuild {
            cmake {
                cppFlags ""
            }
        }
    }
    externalNativeBuild {
        cmake {
            path file("src/main/cpp/CMakeLists.txt")
            version "3.18.1"
        }
    }
}
```

## Important Limitations on Android GPIO Access

While the above technical pipeline (**Kotlin -> JNI -> C -> Linux System Calls**) is how native code execution works,  
controlling GPIO directly from a standard Android application face **significant security roadblocks**:

+ **Permissions & Sandboxing**:  
  Standard Android apps run inside a sandboxed user ID (`u0_a`...)  
  and do **not** have read/write access to system paths like `/sys/class/gpio` or `/dev/mem`  
  due to **strict SELinux policies and file permissions**.
+ Requirements for Real-World Deployment:
  1. **Root Access**: If you are building for a rooted development board  
     (like a Raspberry Pi running Android, or custom embedded hardware),  
     your app or the native binary may need `su` permissions.
  2. **System App/ Custom ROM**: If you are manufacturing an embedded Android device (OEM),  
     you can sign your app with the `platform certificate`, declare it as a **system app**,  
     or modify the SELinux policy (`sepolicy`) and init scripts (`init.r`c)  
     to grant the app ownership or access rights to the specific GPIO nodes.
  3. Hardware Abstraction Layer (HAL):  
     **In production Android architecture, standard apps do not touch GPIO directly.**  
     Instead, they call a custom **Android Service**,  
     which communicates with a vendor-specific HAL, which in turn executes the low-level C/C++ code **with proper system privileges**.

## advantages: using c code

When developing an Android application that needs to interact with hardware like GPIO,  
using C code via the **NDK (Native Development Kit)** offers several critical advantages  
over writing everything in pure Kotlin or Java.

1. **Direct Hardware and System-Level Access:**
   + **Low-Level Control**: C allows you to **directly** use Linux system calls (`open()`, `read()`, `write()`, `ioctl()`, `mmap()`)  
     to interact with device drivers, memory-mapped I/O, and kernel interfaces (`/sys/class/gpio` or `/dev/gpiomem`).
   + Pointer Arithmetic and Bit Manipulation: Controlling hardware often requires precise manipulation of bits, registers, and memory addresses.  
     C provides native, highly efficient support for pointers and bitwise operations that Kotlin and Java abstract away or handle less efficiently.
2. Maximum Performance and Minimal Latency
   + **No Virtual Machine Overhead**: Kotlin and Java run on the Android Runtime (ART) and use Garbage Collection (GC).  
     GC pauses can introduce unpredictable latency (jitter),  
     which is disastrous if your GPIO needs to toggle pins with microsecond precision  
     (e.g., bit-banging a protocol, software PWM, or reading fast sensors).  
     C code runs directly on the CPU with zero runtime overhead.
   + Speed: C executes raw machine instructions compiled specifically for your target architecture (ARM, x86, etc.),  
     ensuring the fastest possible execution time.
3. **Reuse of Existing C/C++ Libraries and Drivers:**
   + Vendor SDKs: Most hardware vendors, microcontrollers, and sensor manufacturers  
     (like those providing Linux drivers or embedded peripherals)  
     write their reference drivers, SDKs, and libraries in C or C++.
   + Portability: Instead of rewriting complex protocol parsers or hardware drivers from scratch in Kotlin,  
     you can directly integrate existing, battle-tested C libraries into your Android app via JNI.
4. Code Security and Reverse Engineering Protection
   + Compiled Binaries: While Kotlin and Java bytecode can be relatively easily decompiled back into readable source code,  
     C code compiles into native machine code (.so shared libraries).  
     This makes it significantly harder to reverse-engineer proprietary algorithms,  
     hardware communication protocols, or security keys embedded in the native layer.

## Comparison

### Feature of Kotlin / Java

+ Hardware/ System Calls: **Restricted** (Sandboxed/ No direct file descriptor access to low-level nodes)
+ Execution Speed: Slower (Interpreted/JIT compiled, managed memory)
+ Memory Management: Automatic (Garbage Collected - can cause pauses)
+ Real-time Performance: Poor (GC pauses can cause timing jitter)

### Feature of C (via NDK)

+ Hardware/ System Calls: **Direct** (`open`, `ioctl`, `mmap`, **raw pointers**)
+ Execution Speed: Maximum (Compiled straight to machine code)
+ Memory Management: Manual (`malloc`/`free` or direct hardware addressing)
+ Real-time Performance: Excellent (Deterministic execution timing)
