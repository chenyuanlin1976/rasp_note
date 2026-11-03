# JNI introduction

**JNI (Java Native Interface)** is the standard interface that lets code running in a Java runtime
(the JVM on desktop, **ART** on Android) call functions written in **C/C++**, and lets those functions call back into Java.
Kotlin/JVM and Kotlin on Android use the same mechanism.

+ JNI works **inside one process**. The Java code and the native library share the same address space, UID, and SELinux domain.
+ On Android, you build the native side with the **NDK** (see [NDK_intro.md](NDK_intro.md)).
  The NDK compiles C/C++ into a shared library (`libfoo.so`) that is packaged in the APK.

## 1. How it works

```text
[ Kotlin / Java ]      external fun add(a: Int, b: Int): Int     System.loadLibrary("native-lib")
        |  ART looks up the native symbol (by name, or registered in JNI_OnLoad)
        v
[ JNI boundary ]       arguments converted: Int -> jint, String -> jstring (a reference), ...
        v
[ C/C++ in libnative-lib.so ]   receives JNIEnv*, can call back into Java through it
        |  normal system calls, with the SAME privileges as the app process
        v
[ Kernel ]
```

A minimal example:

```kotlin
package com.example.app

object NativeLib {
    init { System.loadLibrary("native-lib") }     // loads libnative-lib.so
    @JvmStatic external fun add(a: Int, b: Int): Int
}
```

```c++
#include <jni.h>

extern "C" JNIEXPORT jint JNICALL
Java_com_example_app_NativeLib_add(JNIEnv* env, jclass clazz, jint a, jint b) {
    return a + b;
}
```

The complete Android Studio setup (Gradle, CMake, naming rules, types, threads) is in [JNI_android_studio.md](JNI_android_studio.md).

## 2. When to use JNI

+ **Reusing existing C/C++ libraries**: OpenCV, FFmpeg, SQLite, a vendor SDK, or cross-platform code shared with iOS.
+ **Compute-heavy hot loops**: codecs, signal/image processing, physics, game engines, Vulkan/OpenGL ES rendering.
  Benchmark first, though. ART's AOT/JIT-compiled Kotlin is often fast enough, and JNI calls have overhead.
+ **NDK-only APIs**: AAudio, the Vulkan loader, `ANativeWindow`, and native camera/media APIs.

## 3. When *not* to use JNI

+ **To get hardware or system access.** Native code has **no extra privileges**: it runs with the app's UID and SELinux domain.
  If Kotlin can't open `/sys/class/leds/...`, C can't either.
  Hardware access belongs in a privileged service or HAL, which the app calls over Binder (AIDL).
  See [JNI_C_code.md](JNI_C_code.md).
+ **For security through obscurity.** A `.so` is harder to read than DEX bytecode, but it's still easy to disassemble,
  and strings or keys in it are easy to extract. Don't keep secrets there.
+ **For small or frequent calls.** Each crossing costs time (argument conversion, reference management),
  so lots of tiny calls can be **slower** than pure Kotlin. Batch the work so there are few crossings.

## 4. Costs and risks

+ **Crashes**: a bug in Kotlin throws a catchable exception.
  A bug in C/C++ (segfault, buffer overflow, use-after-free) kills the **whole process** with a native crash (tombstone).
+ **Memory**: native allocations (`malloc`/`new`) aren't garbage-collected.
  JNI **references** must be managed too (local vs global references; see [JNI_android_studio.md](JNI_android_studio.md)).
+ **Security**: native code bypasses Kotlin's bounds checks, so memory-safety bugs become exploitable.
  On Android, the VM is **not** a security boundary: the real sandbox is the process (UID + SELinux), and native code is inside it.
+ **Tooling**: you need the NDK, CMake, per-ABI builds (`arm64-v8a`, `x86_64`, ...), and native debugging (LLDB).

## 5. JNI vs AIDL

They solve different problems:

| | JNI | AIDL (Binder) |
| --- | --- | --- |
| Crosses | The **language** boundary (Java ↔ C/C++) | The **process** boundary (process A ↔ process B) |
| Same process? | Yes | No (usually) |
| Privileges | Exactly the caller's | The callee's: a privileged service can do what the caller can't |
| Generated code | None (you write the bridge) | Proxy/stub generated for Java, C++, Rust |

For "app controls hardware", the modern design needs **no JNI at all**:

```text
App (Kotlin) --Binder/AIDL--> system app / service --Binder/stable AIDL--> native C++ HAL (NDK backend) --> /sys, /dev
```

The AIDL compiler generates both the Java proxy and the C++ stub, so no hand-written JNI bridge is involved.
JNI shows up only where Java code must call a native library **in its own process**.
Pre-Treble framework services (for example the old LightsService, which loaded `libhardware` modules into `system_server`) worked that way.
See [libgpiod_HAL.md](libgpiod_HAL.md) and [AIDL_impl_leds_cxx.md](AIDL_impl_leds_cxx.md).

## 6. Alternatives to hand-written JNI

| Option | Where it works | Notes |
| --- | --- | --- |
| Native AIDL service (C++/Rust) | Android platform/vendor | Cross-process; no JNI; see [AIDL_HAL_impl.md](AIDL_HAL_impl.md) |
| JNA (Java Native Access) | Desktop JVM; also Android (with its own `.so`) | No glue code, but slower than JNI |
| Panama FFM API (`java.lang.foreign`) | Desktop JDK 22+ | **Not available on Android/ART** |
| Kotlin/Native `cinterop` | Kotlin Multiplatform native targets (iOS, Linux, ...) | Not the Kotlin/JVM or Android-ART path |
| Code generators (SWIG, djinni, `jni-rs` for Rust) | Any JVM | Generate the JNI glue for you |

## Related notes

+ [JNI_android_studio.md](JNI_android_studio.md): building a JNI library step by step
+ [JNI_C_code.md](JNI_C_code.md): native code, hardware access, and privileges
+ [NDK_intro.md](NDK_intro.md), [AIDL_intro.md](AIDL_intro.md), [HAL_intro.md](HAL_intro.md)

## Reference

+ [JNI tips (Android)](https://developer.android.com/training/articles/perf-jni)
+ [JNI specification (Oracle)](https://docs.oracle.com/en/java/javase/21/docs/specs/jni/index.html)
