# JAR and AAR libraries

JAR and AAR are the two standard formats for shipping a library to Android developers.
Both contain compiled Java/Kotlin code. They differ in what else they can carry.

A typical use case in these notes: a client SDK for a GPIO service exposed by a system app
(see [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md)).

## 1. JAR (Java Archive)

A JAR is the standard Java format: a ZIP file with compiled `.class` files and a `META-INF/MANIFEST.MF`.

+ **Contains**: compiled classes (Java, Kotlin, generated AIDL stubs) and plain Java resources
  (files read with `ClassLoader.getResource()`).
+ **Cannot contain**: Android resources (`res/`, so no `R` class), an `AndroidManifest.xml`,
  or native libraries in a form the Android build packages into the APK.
+ **Platform**: the format is plain Java, but the content decides where it runs.
  Classes generated from `.aidl` use `android.os.IBinder`, `Binder` and `Parcel`,
  so a JAR with AIDL stubs is compiled against `android.jar` and only runs on Android.
+ **Code may still use Android APIs**: a helper that takes a `Context` and calls `bindService()` fits in a JAR.
  What a JAR can't do is bring its own resources or manifest entries.

## 2. AAR (Android Archive)

An AAR is the Android library format, also a ZIP file. An Android library module
(`com.android.library` plugin) builds it into `build/outputs/aar/`.

```text
gpio-sdk-release.aar
├── AndroidManifest.xml      required; merged into the app's manifest
├── classes.jar              compiled code, including AIDL stubs
├── R.txt                    resource IDs of the library
├── res/                     layouts, values, drawables (optional)
├── assets/                  raw assets (optional)
├── libs/*.jar               bundled JAR dependencies (optional)
├── jni/<abi>/*.so           native libraries, e.g. jni/arm64-v8a/ (optional)
├── proguard.txt             consumer R8/ProGuard rules (optional)
└── lint.jar                 custom lint checks (optional)
```

+ **Manifest**: `<uses-permission>`, `<queries>`, components such as services or receivers.
  The manifest merger copies them into every app that uses the library
  (see [AndroidManifest.md](AndroidManifest.md)).
+ **Native code**: `.so` files for JNI, per ABI.
+ **Consumer rules**: `consumerProguardFiles` in the library module end up as `proguard.txt`,
  so the app's R8 run keeps the classes the library needs.

## 3. Comparison

| Feature                         | JAR                                  | AAR                                              |
| ------------------------------- | ------------------------------------ | ------------------------------------------------ |
| Format                          | Standard Java                        | Android only                                     |
| Compiled code (`.class`)        | Yes                                  | Yes (`classes.jar`)                              |
| Code using Android APIs         | Yes (compiled against `android.jar`) | Yes                                              |
| Android resources (`res/`, `R`) | No                                   | Yes                                              |
| `AndroidManifest.xml`           | No                                   | Yes                                              |
| Native libraries (`.so`)        | No                                   | Yes (`jni/<abi>/`)                               |
| Consumer R8/ProGuard rules      | Via `META-INF/proguard/*.pro`        | Yes (`proguard.txt`)                             |
| Consumed by                     | Any Java build                       | Android builds (AGP, Soong `android_library_import`) |

For the GPIO SDK:

+ **JAR**: only the AIDL stubs, parcelables and a small helper class.
  The client app adds the `<queries>` and `<uses-permission>` entries to its own manifest.
+ **AAR**: a full SDK, for example a `GpioManager` wrapper that hides the binding,
  plus the manifest entries the client would otherwise have to add by hand.

## 4. Build and consume

### Build

+ **Gradle**: an Android library module produces the AAR.
  If you need a JAR with AIDL stubs, take `classes.jar` out of the AAR, because a plain `java-library` module can't compile `.aidl` files and has no `android.jar`.
+ **AOSP (Soong)**: `java_library` builds a JAR, `android_library` builds an Android library with resources
  (see [Android_bp_intro.md](Android_bp_intro.md)).

```kotlin
// gpio-sdk/build.gradle.kts
plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.gpio.sdk"
    compileSdk = 35
    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }
    buildFeatures {
        aidl = true
    }
}
```

### Consume

```kotlin
// app/build.gradle.kts
dependencies {
    // Preferred: published to a Maven repository (the POM brings transitive dependencies)
    implementation("com.example.gpio:gpio-sdk:1.0.0")

    // Local files in app/libs/
    implementation(files("libs/gpio-sdk.aar"))
    implementation(files("libs/gpio-aidl.jar"))
}
```

+ A local file dependency carries **no transitive dependencies**; the app has to declare them itself.
+ AGP refuses direct local `.aar` dependencies in a **library** module that is itself built as an AAR.
  Publish the AAR to a (local) Maven repository with the `maven-publish` plugin instead.

## Related notes

+ [AIDL_3rdParty_app.md](AIDL_3rdParty_app.md), [AIDL_binding.md](AIDL_binding.md)
+ [AndroidManifest.md](AndroidManifest.md), [Android_bp_intro.md](Android_bp_intro.md), [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md)
+ [JNI_android_studio.md](JNI_android_studio.md), [NDK_intro.md](NDK_intro.md)

## Reference

+ [Create an Android library](https://developer.android.com/studio/projects/android-library)
+ [Add build dependencies](https://developer.android.com/build/dependencies)
+ [Merge multiple manifest files](https://developer.android.com/build/manage-manifests)
+ [Shrink, obfuscate, and optimize your app](https://developer.android.com/build/shrink-code)
+ [JAR File Specification](https://docs.oracle.com/en/java/javase/17/docs/specs/jar/jar.html)
