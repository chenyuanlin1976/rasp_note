# Android app project structure (Gradle)

This note describes the directory layout of an Android Studio (Gradle) app project and how to organize the source code inside it.
It covers app projects only. For the platform source tree and `Android.bp`, see [../Build/AOSP_build_system.md](../Build/AOSP_build_system.md) and [../Build/Android_bp_intro.md](../Build/Android_bp_intro.md).

## 1. Project layout

A new project with one app module looks like this:

```text
MyProject/
├── settings.gradle.kts          repositories, list of modules (include(":app"))
├── build.gradle.kts             top-level: plugins declared with "apply false"
├── gradle.properties            Gradle/JVM flags (org.gradle.jvmargs, android.useAndroidX)
├── local.properties             SDK path (sdk.dir); machine-specific, not committed
├── gradle/
│   ├── libs.versions.toml       version catalog (libs.*)
│   └── wrapper/                 Gradle wrapper jar and gradle-wrapper.properties
├── gradlew, gradlew.bat         wrapper scripts: always build with ./gradlew
└── app/                         the app module
    ├── build.gradle.kts         android { namespace, applicationId, compileSdk, minSdk, targetSdk, buildTypes }
    ├── proguard-rules.pro       R8 keep rules for release builds
    ├── build/                   build output (APKs, generated code); not committed
    └── src/
        ├── main/                source set used by every build variant
        │   ├── AndroidManifest.xml
        │   ├── java/            Kotlin and/or Java sources (kotlin/ also works)
        │   ├── res/             resources (section 2)
        │   ├── assets/          raw files read with AssetManager (optional)
        │   ├── cpp/             native code + CMakeLists.txt (optional, NDK)
        │   └── jniLibs/         prebuilt .so files per ABI (optional)
        ├── debug/               extra code/resources/manifest for the debug build type (optional)
        ├── test/                local unit tests (JVM, no device)
        └── androidTest/         instrumented tests (run on a device or emulator)
```

| File | Level | What it holds |
| --- | --- | --- |
| `settings.gradle.kts` | Project | `pluginManagement` and `dependencyResolutionManagement` repositories, `include(...)` of every module |
| `build.gradle.kts` (root) | Project | Plugins shared by modules, usually with `apply false` |
| `app/build.gradle.kts` | Module | The `android { }` block, build types and flavors, dependencies |
| `gradle/libs.versions.toml` | Project | Versions of libraries and plugins, referenced as `libs.*` |
| `AndroidManifest.xml` | Source set | Components, permissions, features ([AndroidManifest.md](AndroidManifest.md)) |

`namespace` sets the package of the generated `R` and `BuildConfig` classes.
`applicationId` is the app's unique ID on the device and in Play. They often have the same value, but they are separate settings.

## 2. Resources (`res/`)

| Directory | Contents |
| --- | --- |
| `layout/` | XML layouts (not needed for Compose-only UIs) |
| `values/` | `strings.xml`, `colors.xml`, `themes.xml`, `dimens.xml` |
| `drawable/` | Vector drawables, shapes, bitmaps |
| `mipmap-*/` | Launcher icons only, one folder per density |
| `xml/` | Other XML config (e.g. `network_security_config.xml`, file provider paths) |
| `raw/` | Raw files opened with `R.raw.*` |
| `navigation/` | Jetpack Navigation graphs (if used) |

Qualifiers select alternatives at run time: `values-zh-rTW/`, `values-night/`, `layout-land/`, `drawable-hdpi/`.
The build generates an `R` class with one ID per resource, such as `R.layout.activity_main` or `R.string.app_name`.

## 3. Organizing packages

The package `com.example.app.ui` is the directory `app/src/main/java/com/example/app/ui/`.
There are two common ways to split it.

### 3.1 By layer

Classes are grouped by technical role. This is simple and works for small apps.

```text
com.example.app
├── ui/         Activities, Fragments, Composables, ViewModels
├── data/       repositories, Room entities and DAOs, DTOs
└── network/    Retrofit interfaces, API client setup
```

As the app grows, one feature's code ends up spread across every package.

### 3.2 By feature

Each feature gets its own package, with its layers inside. Shared code goes in `core`.

```text
com.example.app
├── core/                  shared utilities, design system, network and database setup
├── feature/login/         ui/, data/ for login
└── feature/profile/       ui/, data/ for the user profile
```

"Clean Architecture" is a different idea from "feature-first".
It is about **layers** and the direction of dependencies (UI → domain → data), and you can apply it inside either layout.
Google's architecture guide describes a UI layer, a data layer, and an optional domain layer.

### 3.3 Packages vs. modules

Packages are only a naming convention: any class can still use any other class.
Gradle **modules** (`:core:data`, `:feature:login`) enforce the boundaries and allow parallel, incremental builds.
Each module has its own `build.gradle.kts` and `src/` tree and is listed in `settings.gradle.kts`.

## 4. Comments

+ For a small app or a demo, one `app` module with feature packages (section 3.2) is enough.
  Split into modules when builds get slow or several people work on separate features.
+ If a feature package will probably become a module later, keep its dependencies one-way from the start (`feature` → `core`, never `core` → `feature`).
  Moving it later is then only a matter of moving files.
+ Commit the wrapper (`gradlew`, `gradle/wrapper/`) and `libs.versions.toml`. Don't commit `local.properties`, `build/` or `.gradle/`.
+ For Google's own example of a modular app, see the Now in Android sample (linked below).

## Related notes

+ [AndroidManifest.md](AndroidManifest.md): the manifest in `src/main/` and manifest merging
+ [gradle_build.md](gradle_build.md): dependencies, repositories, R8
+ [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md): the `android { }` block and the version catalog
+ [jar_aar_intro.md](jar_aar_intro.md), [View_binding.md](View_binding.md)

## Reference

+ [Projects overview (Android)](https://developer.android.com/studio/projects)
+ [App resources overview (Android)](https://developer.android.com/guide/topics/resources/providing-resources)
+ [Guide to app architecture (Android)](https://developer.android.com/topic/architecture)
+ [Guide to Android app modularization (Android)](https://developer.android.com/topic/modularization)
+ [Now in Android sample (GitHub)](https://github.com/android/nowinandroid)
