# NDK (Native Development Kit)

The NDK is the toolset for building **C and C++ code inside Android apps**:
a Clang/LLVM toolchain, a sysroot with the stable native APIs, and integration with CMake / ndk-build and Gradle.
The output is a shared library (`libfoo.so`) per ABI, packaged in the APK and loaded into the app's process.

Native code in an app runs with the **same UID, SELinux domain, and permissions as the app's Java/Kotlin code**.
It doesn't escape the app sandbox and gives no extra hardware access.

## 1. NDK vs the AOSP build

| | NDK (app developers) | AOSP / Soong (platform and vendor developers) |
| --- | --- | --- |
| Builds | `.so` libraries inside an APK | Platform and vendor binaries: daemons, HALs, system libraries |
| Tooling | Android Studio + Gradle + CMake (or ndk-build) | `Android.bp` (`cc_binary`, `cc_library`), the platform's Clang |
| APIs | Only the **stable NDK APIs** (`libc`, `libm`, `liblog`, `libandroid`, `libbinder_ndk` (limited), AAudio, Vulkan, ...) | Platform libraries; vendor code uses VNDK / LLNDK / NDK-backend stable ABIs |
| Runs as | The app's process | Its own process with its own UID/domain ([native_daemon.md](native_daemon.md)) |

The **"NDK backend" of AIDL** (`libbinder_ndk`, `ndk::ScopedAStatus`) is named after the NDK because it is a stable C ABI.
Vendor HALs use it, but they are built with Soong, not with the NDK download.
See [../IPC/AIDL_backends.md](../IPC/AIDL_backends.md) and [../HAL/AIDL_HAL_impl.md](../HAL/AIDL_HAL_impl.md).

## 2. When an app needs native code

+ **Reusing C/C++ libraries**: codecs, OpenCV, SQLite extensions, game engines, cross-platform core logic.
+ **CPU-heavy loops** that benefit from SIMD (NEON) or tight memory control: DSP, image processing, physics.
+ **Low-latency graphics and audio**: Vulkan / OpenGL ES, AAudio (via Oboe).

Not good reasons:

+ "Native is faster": ART's JIT/AOT code is fast for normal app logic, and each JNI call has a cost.
+ "Access to hardware": the native code has the app's permissions. Hardware access goes through framework APIs or a system service / HAL.

## 3. What the NDK provides

| Part | Notes |
| --- | --- |
| Toolchain | Clang/LLVM only (GCC was removed in NDK r18). libc++ is the C++ standard library |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86` (see the ABI guide for newer additions) |
| Stable APIs | Headers + stub libraries per API level. The `minSdk` decides which functions are available |
| Build systems | CMake (default in Android Studio), ndk-build (`Android.mk`, legacy) |
| Audio | AAudio (API 26+). **OpenSL ES is deprecated**; use the Oboe library, which wraps AAudio |

Since **Android 7.0**, apps can't dynamically link non-NDK (private) platform libraries.
A library that links them, even indirectly through a 3rd-party static library, crashes at load time.

## 4. Gradle setup

```kotlin
// app/build.gradle.kts
android {
    ndkVersion = "27.0.12077973"                 // pin the installed NDK (SDK Manager > SDK Tools > NDK)
    defaultConfig {
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }
    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }
}
```

The complete JNI example (CMake, Kotlin, C++) is in [JNI_android_studio.md](JNI_android_studio.md).

**16 KB pages**: devices with 16 KB memory pages are supported since Android 15.
Native libraries must be built with 16 KB ELF alignment, and Google Play requires this for apps that target Android 15+.
AGP 8.5.1+ with **NDK r28+** does it by default. Older NDKs need the linker flag `-Wl,-z,max-page-size=16384`.

## 5. NDK and JNI

| | NDK | JNI |
| --- | --- | --- |
| What | Toolchain + native APIs | The interface between Java/Kotlin and native code in **one process** |
| Answers | "How do I compile C/C++ for Android?" | "How does Kotlin call my C++ function?" |

+ App with a C++ library: compile it with the **NDK**, call it through **JNI**.
+ App that is entirely native (`NativeActivity`, games): the NDK only, with minimal JNI glue.
+ Native daemon or HAL: neither the NDK download nor JNI. It's built with Soong and reached through Binder ([native_daemon.md](native_daemon.md)).

## Related notes

+ [JNI_intro.md](JNI_intro.md), [JNI_android_studio.md](JNI_android_studio.md), [JNI_C_code.md](JNI_C_code.md)
+ [native_daemon.md](native_daemon.md), [../IPC/AIDL_backends.md](../IPC/AIDL_backends.md)

## Reference

+ [NDK guides](https://developer.android.com/ndk/guides)
+ [NDK stable APIs](https://developer.android.com/ndk/guides/stable_apis)
+ [ABIs](https://developer.android.com/ndk/guides/abis)
+ [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
+ [Android 7.0 behavior change: NDK apps linking to platform libraries](https://developer.android.com/about/versions/nougat/android-7.0-changes)
+ [OpenSL ES (deprecated) and Oboe](https://developer.android.com/ndk/guides/audio/opensl)
