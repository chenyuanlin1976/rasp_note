# Building an Android app with Gradle

Everyday Gradle tasks for an Android Studio project: adding dependencies, building APKs and bundles,
repositories, and code shrinking with R8. The examples use Kotlin DSL (`*.gradle.kts`).
For the Groovy equivalents and the full `android { }` block, see [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md).

## 1. Dependencies

### From a Maven repository (preferred)

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.google.code.gson:gson:2.11.0")
    // or, with a version catalog: implementation(libs.gson)
}
```

Gradle downloads the library and its transitive dependencies from the repositories in `settings.gradle.kts` (section 3).

### Local JAR or AAR files

Use this only for libraries that are not published anywhere, for example a vendor SDK.

1. Copy the file into `app/libs/` (the `libs` folder of the module, not of the project).
2. Add it to the module's `build.gradle.kts`:

   ```kotlin
   dependencies {
       implementation(files("libs/gpio-sdk.jar"))
       // or every JAR and AAR in the folder:
       implementation(fileTree("libs") { include("*.jar", "*.aar") })
   }
   ```

3. Click **Sync Project with Gradle Files**. A `./gradlew clean` is not needed.

+ A local file brings **no transitive dependencies**. Declare them yourself.
+ Android Studio's **Add As Library** context menu writes the same `implementation(files(...))` line.
+ JAR vs. AAR, and why a library module can't depend on a local AAR: [jar_aar_intro.md](jar_aar_intro.md).

## 2. Build from the command line

Run the Gradle wrapper from the project root (`gradlew.bat` on Windows).

| Command | Output |
| --- | --- |
| `./gradlew assembleDebug` | `app/build/outputs/apk/debug/app-debug.apk` (signed with the debug key) |
| `./gradlew assembleRelease` | `app/build/outputs/apk/release/app-release.apk`, or `app-release-unsigned.apk` if no `signingConfig` is set |
| `./gradlew bundleRelease` | `app/build/outputs/bundle/release/app-release.aab` (for Google Play) |
| `./gradlew installDebug` | Builds and installs the debug APK on the connected device |
| `./gradlew tasks` | Lists the available tasks |
| `./gradlew clean` | Deletes `build/` directories (only needed when the build is in a broken state) |

In Android Studio:

+ **Build > Build App Bundle(s) / APK(s)** writes to the same `app/build/outputs/` folders.
+ **Build > Generate Signed App Bundle / APK** asks for a keystore and by default writes to `app/release/`.

Release signing (`signingConfigs`, `apksigner`, platform keys): [sign_apk.md](sign_apk.md).

## 3. Repositories

Gradle resolves non-local dependencies from the repositories in `settings.gradle.kts`,
searching them in the listed order. A new Android Studio project contains:

```kotlin
// settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
```

+ `google()`: Google's Maven repository (AndroidX, AGP, Play services).
+ `mavenCentral()`: most other open-source libraries.
+ `FAIL_ON_PROJECT_REPOS` makes the build fail if a module declares its own `repositories { }`.
+ Add `mavenLocal()` (`~/.m2/repository`) to use a library you published locally with `./gradlew publishToMavenLocal`.
  Put it last, and only during development.

## 4. Version catalog

New projects keep dependency and plugin versions in `gradle/libs.versions.toml` and reference them as `libs.*`.
Gradle reads this file name by default. Syntax and examples: [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md) (section 3).

## 5. Code shrinking with R8

R8 has been the default shrinker in the Android Gradle Plugin (AGP) since 3.4. It replaced ProGuard but reads the same rule syntax.
It only runs when you enable it, usually for the release build type:

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true      // code shrinking, optimization, obfuscation
            isShrinkResources = true    // remove unused resources (needs isMinifyEnabled)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

| Step | What R8 does |
| --- | --- |
| Shrinking | Removes classes, methods, and fields that are not reachable from the entry points |
| Optimization | Inlines methods, removes dead code, merges classes |
| Obfuscation | Renames classes and members to short names. This makes reverse engineering harder but is no real protection |

+ **Keep rules** in `proguard-rules.pro` protect code that is only reached by reflection, JNI, or serialization.
  For example, classes used by Gson or native methods called from C need `-keep` rules.
+ **Libraries** ship their own rules (consumer rules in an AAR), so the app usually doesn't need rules for them.
+ **Mapping file**: `app/build/outputs/mapping/release/mapping.txt` maps the obfuscated names back to the originals.
  Keep it for every release and upload it to Google Play, so crash reports show readable stack traces.
  Use `retrace` to decode a stack trace by hand.
+ Since AGP 8.0, R8 runs in **full mode** by default, which optimizes more aggressively and can need extra keep rules.

## Related notes

+ [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md), [Groovy_intro.md](Groovy_intro.md)
+ [jar_aar_intro.md](jar_aar_intro.md), [app_project_structure.md](app_project_structure.md), [AndroidManifest.md](AndroidManifest.md)
+ [sign_apk.md](sign_apk.md), [JNI_android_studio.md](JNI_android_studio.md)

## Reference

+ [Add build dependencies](https://developer.android.com/build/dependencies)
+ [Build your app from the command line](https://developer.android.com/build/building-cmdline)
+ [Remote repositories](https://developer.android.com/build/remote-repositories)
+ [Migrate your build to version catalogs](https://developer.android.com/build/migrate-to-catalogs)
+ [Shrink, obfuscate, and optimize your app](https://developer.android.com/build/shrink-code)
