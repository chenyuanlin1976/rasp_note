# JNI in Android Studio: step by step

This note builds an app that calls C++ through JNI, using the NDK, CMake, and Kotlin (Android 14+, AGP 8).
For the concepts and when to use JNI, see [JNI_intro.md](JNI_intro.md).

## 1. Project setup

**File > New Project > Native C++** creates everything below.
To add native code to an existing module, use **right-click module > Add C++ to Module**, or add it by hand:

```text
app/src/main/
├── java/com/example/nativedemo/NativeLib.kt
└── cpp/
    ├── CMakeLists.txt
    └── native-lib.cpp
```

`app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.example.nativedemo"
    compileSdk = 34
    ndkVersion = "27.0.12077973"          // pin the NDK version you installed (SDK Manager > SDK Tools)

    defaultConfig {
        minSdk = 24
        targetSdk = 34
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")   // device + emulator; add armeabi-v7a if needed
        }
        externalNativeBuild {
            cmake { cppFlags += "-std=c++17" }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}
```

`app/src/main/cpp/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22.1)
project("nativedemo")

# Builds libnative-lib.so; the name must match System.loadLibrary("native-lib")
add_library(native-lib SHARED native-lib.cpp)

# NDK system libraries: liblog for __android_log_print; add "android" only if you use ANativeWindow, AAsset, ...
find_library(log-lib log)
target_link_libraries(native-lib ${log-lib})
```

## 2. Kotlin side

```kotlin
package com.example.nativedemo

class NativeLib {
    // Instance method -> C function receives (JNIEnv*, jobject thiz, ...)
    external fun stringFromJNI(): String
    external fun sum(values: IntArray): Long

    companion object {
        init { System.loadLibrary("native-lib") }   // runs once, when NativeLib is first used

        // Static method -> C function receives (JNIEnv*, jclass, ...)
        @JvmStatic external fun add(a: Int, b: Int): Int
    }
}
```

**Pitfall**: without `@JvmStatic`, an `external fun` declared inside a `companion object`
becomes an instance method of the nested class `NativeLib$Companion`.
Its JNI name is then `Java_com_example_nativedemo_NativeLib_00024Companion_add`,
and it receives the Companion object, not a `jclass`.
Use `@JvmStatic`, or declare the functions in a top-level `object`.

## 3. C++ side

### 3.1 Static linking by name

```c++
// native-lib.cpp
#include <jni.h>
#include <string>
#include <android/log.h>

#define LOG_TAG "native-lib"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_nativedemo_NativeLib_stringFromJNI(JNIEnv* env, jobject /* thiz */) {
    std::string hello = "Hello from C++";
    return env->NewStringUTF(hello.c_str());          // input must be (Modified) UTF-8
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_nativedemo_NativeLib_add(JNIEnv*, jclass, jint a, jint b) {
    return a + b;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_nativedemo_NativeLib_sum(JNIEnv* env, jobject, jintArray values) {
    jsize n = env->GetArrayLength(values);
    jint* p = env->GetIntArrayElements(values, nullptr);   // may be a copy
    if (p == nullptr) return 0;                             // OutOfMemoryError already pending
    jlong total = 0;
    for (jsize i = 0; i < n; ++i) total += p[i];
    env->ReleaseIntArrayElements(values, p, JNI_ABORT);     // JNI_ABORT: read-only, don't copy back
    return total;
}
```

The **naming rule** is `Java_` + fully qualified class name + `_` + method name.
`.` becomes `_`, and special characters are escaped:

| In the Java name | Becomes |
| --- | --- |
| `.` (package separator) | `_` |
| `_` | `_1` (e.g. `set_value` → `set_1value`) |
| `$` (nested class) | `_00024` |
| Overloaded method | Append `__` + mangled argument signature |

`extern "C"` turns off C++ name mangling, so ART can find the symbol by its plain name.

### 3.2 Registering in `JNI_OnLoad` (recommended for bigger libraries)

With `RegisterNatives`, the names don't need to follow the `Java_...` rule.
A typo fails right away at load time instead of at the first call, and fewer symbols are exported.

```c++
static jint nativeAdd(JNIEnv*, jclass, jint a, jint b) { return a + b; }

static const JNINativeMethod kMethods[] = {
    // { Java method name, JNI type signature, function pointer }
    {"add", "(II)I", reinterpret_cast<void*>(nativeAdd)},
};

JavaVM* gVm = nullptr;

extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void*) {
    gVm = vm;
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;

    jclass cls = env->FindClass("com/example/nativedemo/NativeLib");
    if (cls == nullptr) return JNI_ERR;
    if (env->RegisterNatives(cls, kMethods, sizeof(kMethods) / sizeof(kMethods[0])) != JNI_OK) {
        return JNI_ERR;
    }
    return JNI_VERSION_1_6;
}
```

Here `add` is the `@JvmStatic` method, so its native function receives a `jclass`.
JNI type signatures: `I` int, `J` long, `Z` boolean, `B` byte, `C` char, `S` short, `F` float, `D` double, `V` void,
`Ljava/lang/String;` an object, `[I` an int array.
`javap -s` prints the signatures of a compiled class.

## 4. Type mapping

| Kotlin / Java | JNI type | C/C++ size |
| --- | --- | --- |
| `Boolean` | `jboolean` | `uint8_t` (`JNI_TRUE` = 1, `JNI_FALSE` = 0) |
| `Byte` | `jbyte` | `int8_t` |
| `Char` | `jchar` | `uint16_t` (UTF-16 unit) |
| `Short` | `jshort` | `int16_t` |
| `Int` | `jint` | `int32_t` |
| `Long` | `jlong` | `int64_t` |
| `Float` / `Double` | `jfloat` / `jdouble` | `float` / `double` |
| `String` | `jstring` | Reference; convert with `GetStringUTFChars`/`ReleaseStringUTFChars` (Modified UTF-8) |
| `IntArray`, `ByteArray`, ... | `jintArray`, `jbyteArray`, ... | Reference; `Get<Type>ArrayRegion` (copy) or `Get<Type>ArrayElements`/`Release...` |
| `ByteBuffer.allocateDirect()` | `jobject` | `GetDirectBufferAddress` gives a raw pointer with no copy |
| Any other object | `jobject` / `jclass` | Reference |

## 5. Rules that prevent crashes

+ **`JNIEnv*` is per thread.** Don't keep it or pass it to another thread.
  A native thread you created must call `gVm->AttachCurrentThread(&env, nullptr)` before using JNI,
  and `DetachCurrentThread()` before it exits.
+ **Local references** (every `jobject` that JNI returns) are valid only until the native method returns.
  There's a limited number of them, so call `DeleteLocalRef` inside loops.
  To keep an object across calls or threads, use `NewGlobalRef` and later `DeleteGlobalRef`.
  Never store a plain `jobject` or `jclass` in a global variable.
+ **Cache class and method IDs in `JNI_OnLoad`.**
  `FindClass` on an attached native thread uses the system class loader and can't find your app's classes.
  Cache `jclass` as a global reference; `jmethodID`/`jfieldID` can be cached directly.
+ **Exceptions**: after a JNI call that can throw (`CallVoidMethod`, `NewStringUTF`, ...), check `env->ExceptionCheck()`.
  While an exception is pending, you may call only a few cleanup functions; return as soon as possible.
  To report errors to Kotlin, call `env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), "msg")` and return.
+ **Every `Get...` needs its `Release...`**: `GetStringUTFChars`/`ReleaseStringUTFChars`,
  `Get<Type>ArrayElements`/`Release<Type>ArrayElements`.
+ **Debugging**: CheckJNI is on by default on emulators; on a device, run `adb shell setprop debug.checkjni 1` and restart the app.
  It catches many of these mistakes with a clear abort message.
  Native crashes show up as tombstones in `adb logcat`; symbolize them with `ndk-stack`.

## 6. ABIs and page size

+ Google Play has required **64-bit** native code (`arm64-v8a`, plus `x86_64` if you ship x86) since 2019.
  Some newer devices are 64-bit only, so a 32-bit-only `.so` won't load on them.
  Android 14 itself still runs 32-bit apps on devices that have 32-bit support.
+ **16 KB page size**: some Android 15+ devices use 16 KB memory pages.
  Native libraries must be built with 16 KB ELF alignment: NDK r28+ does this by default,
  and older NDKs need `-Wl,-z,max-page-size=16384`.
  Google Play requires this for app updates that target Android 15+.
+ ART runs the Kotlin side. Dalvik was replaced by ART in Android 5.0, so "Dalvik" doesn't apply to Android 14.

## Related notes

+ [JNI_intro.md](JNI_intro.md), [JNI_C_code.md](JNI_C_code.md), [NDK_intro.md](NDK_intro.md)
+ [../../DevTools/CMakeLists_syntax.md](../../DevTools/CMakeLists_syntax.md)

## Reference

+ [Add C and C++ code to your project](https://developer.android.com/studio/projects/add-native-code)
+ [JNI tips](https://developer.android.com/training/articles/perf-jni)
+ [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
