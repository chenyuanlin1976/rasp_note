# Android Studio: project icons and build variants

This note covers two parts of the Android Studio UI that map directly to the Gradle build: the icons in the Project window and the Build Variants panel.
The Gradle side is in [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md) and [gradle_build.md](gradle_build.md).

## 1. Project window icons

The icon of a module comes from the Gradle plugin in its `build.gradle.kts`:

| Icon (approximate) | Module type | Plugin |
| --- | --- | --- |
| Folder with a green dot / phone badge | App module (builds an APK/AAB) | `com.android.application` |
| Folder with three vertical bars | Android library (builds an AAR) | `com.android.library` |
| Folder with a coffee cup | Pure Java/Kotlin library (a JAR, no Android resources) | `java-library` / `org.jetbrains.kotlin.jvm` |

Folder colors inside a module:

| Folder | Meaning |
| --- | --- |
| Blue | Source root (`src/main/java`, `src/main/kotlin`) |
| Green | Test source root (`src/test/...`, `src/androidTest/...`) |
| Folder with a resource badge | Resource root (`res/`, `resources/`) |
| Orange | Excluded from indexing (e.g. `build/`) |

Icons change between Android Studio versions. If you aren't sure, check the plugin in the module's build file, or **File > Project Structure > Modules**.
The project layout itself is in [app_project_structure.md](app_project_structure.md).

## 2. Build variants

A **build variant** is one combination of a **build type** and a **product flavor** (one per flavor dimension):

| | Build type | Product flavor |
| --- | --- | --- |
| Describes | How the app is built (for developers) | Which version of the app (for users) |
| Examples | `debug`, `release` | `free` / `paid`, `staging` / `production` |
| Created by default | `debug` and `release` | None |

With two build types and two flavors you get four variants: `freeDebug`, `freeRelease`, `paidDebug`, `paidRelease`.
Each variant has its own Gradle tasks (`./gradlew assembleFreeDebug`) and its own source set (`src/free/`, `src/freeDebug/`), which is merged with `src/main/`.

```kotlin
// app/build.gradle.kts
android {
    buildTypes {
        debug {
            applicationIdSuffix = ".debug"     // debug and release can be installed side by side
        }
        release {
            isMinifyEnabled = true             // off in a new project's template; turn it on yourself
            signingConfig = signingConfigs.getByName("release")
        }
    }

    flavorDimensions += "tier"
    productFlavors {
        create("free") {
            dimension = "tier"
            applicationIdSuffix = ".free"
        }
        create("paid") {
            dimension = "tier"
        }
    }
}
```

+ `debug` is debuggable and signed automatically with the debug keystore (`~/.android/debug.keystore`).
+ `release` isn't debuggable. It needs your own signing config ([sign_apk.md](sign_apk.md)), and R8 shrinking is enabled only if you set `isMinifyEnabled = true` ([gradle_build.md](gradle_build.md), section 5).
+ Every flavor must belong to a dimension declared in `flavorDimensions`.
+ Typical uses: separate API endpoints per environment, features enabled per tier, and resources or assets that exist in only one variant (`src/staging/`).

### 2.1 The Build Variants panel

Open it with **View > Tool Windows > Build Variants** (or the tab on the left edge of the window).
It lists every module with an **Active Build Variant** drop-down. The selected variant is what **Run**, **Debug** and **Build** use, and the editor shows that variant's source sets as active.

After you change build types or flavors in a build file, click **Sync Now**. The panel only shows variants after a Gradle sync.

## 3. Comments

+ **Keep the variant count small.** Each dimension multiplies the number of variants, and every variant adds configuration and build time. Two dimensions are usually the practical limit.
+ **Use `applicationIdSuffix` for debug builds.** Then a debug build and the store version can be installed on the same phone without one replacing the other.
+ **Prefer flavors over `if (BuildConfig.DEBUG)` for real product differences.** Flavor source sets keep code that only one version needs out of the other APKs.
+ **The panel is just a view of Gradle.** Anything you set there, you can also do on the command line (`./gradlew assemblePaidRelease`), which is what CI uses.

## Related notes

+ [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md): the `android { }` block
+ [gradle_build.md](gradle_build.md): dependencies, command-line builds, R8
+ [app_project_structure.md](app_project_structure.md): modules and source sets
+ [sign_apk.md](sign_apk.md): release signing
+ [AOSP_build_system.md](AOSP_build_system.md): the different `user`/`userdebug`/`eng` build variants of AOSP

## Reference

+ [Configure build variants (Android)](https://developer.android.com/build/build-variants)
+ [Projects overview (Android)](https://developer.android.com/studio/projects)
+ [Android Studio user guide (Android)](https://developer.android.com/studio/intro)
