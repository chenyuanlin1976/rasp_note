# Gradle build scripts: Groovy vs Kotlin DSL

The same Android build written in Groovy (`build.gradle`) and in Kotlin DSL (`build.gradle.kts`).
Kotlin DSL has been the default for new projects since Android Studio Giraffe.
Groovy syntax basics are in [Groovy_intro.md](Groovy_intro.md).

## 1. Differences at a glance

| Item | Groovy (`build.gradle`) | Kotlin DSL (`build.gradle.kts`) |
| --- | --- | --- |
| Files | `build.gradle`, `settings.gradle` | `build.gradle.kts`, `settings.gradle.kts` |
| Typing | Dynamic: errors show up when Gradle runs | Static: errors in the IDE / at script compilation |
| Property assignment | `compileSdk = 34` (the old `compileSdk 34` is deprecated since Gradle 8.12) | `compileSdk = 34` |
| Strings | `'text'` or `"text"` (only `"..."` interpolates `$var`) | `"text"` only (`'c'` is a `Char`); `"$var"` interpolates |
| Method calls | Parentheses optional: `implementation 'g:a:v'` | Parentheses required: `implementation("g:a:v")` |
| Boolean properties | `minifyEnabled = true` | `isMinifyEnabled = true` (Kotlin `is` prefix) |
| Lists / maps | `['a', 'b']`, `[k: 'v']` | `listOf("a", "b")`, `mapOf("k" to "v")` |
| Named containers | `release { }` | `release { }` or `getByName("release") { }`; new entries: `create("staging") { }` |
| Extra properties | `ext.myVer = '1.0'`, then `myVer` | `val myVer by extra("1.0")`, then `rootProject.extra["myVer"]` |

## 2. Plugins and dependencies (with a version catalog)

New projects keep versions in `gradle/libs.versions.toml` and refer to them as `libs.*` from both DSLs:

```toml
# gradle/libs.versions.toml
[versions]
agp = "8.5.2"
kotlin = "2.0.20"
coreKtx = "1.13.1"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
```

```groovy
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

dependencies {
    implementation libs.androidx.core.ktx
    implementation 'androidx.appcompat:appcompat:1.7.0'     // a plain coordinate also works
    testImplementation 'junit:junit:4.13.2'
}
```

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation("androidx.appcompat:appcompat:1.7.0")
    testImplementation("junit:junit:4.13.2")
}
```

Dashes in the catalog become dots in the accessor: `androidx-core-ktx` is `libs.androidx.core.ktx`.

## 3. The `android { }` block

```groovy
android {
    namespace = 'com.example.app'          // required since AGP 8 (replaces the manifest "package")
    compileSdk = 34

    defaultConfig {
        applicationId = 'com.example.app'
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = '1.0'
    }

    buildTypes {
        release {
            minifyEnabled = true
            shrinkResources = true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

```kotlin
android {
    namespace = "com.example.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

## 4. Custom tasks

```groovy
tasks.register('printVersion') {
    doLast { println "versionName = ${android.defaultConfig.versionName}" }
}
```

```kotlin
tasks.register("printVersion") {
    doLast { println("versionName = ${android.defaultConfig.versionName}") }
}
```

Use `tasks.register` (lazy) instead of the old `task printVersion { }` / `tasks.create`.

## 5. Migrating a project to Kotlin DSL

1. Convert `settings.gradle` first, then one module at a time: rename the file to `.kts` and fix the errors that the IDE reports.
   Groovy and Kotlin build files can be mixed in one project.
2. Typical edits: `'` → `"`, add `=` and parentheses, `minifyEnabled` → `isMinifyEnabled`, `[...]` → `listOf(...)`, `ext` → `extra`.
3. Move versions into `libs.versions.toml`, so both DSLs share them during the transition.

## Related notes

+ [Groovy_intro.md](Groovy_intro.md), [Kotlin_DSL.md](Kotlin_DSL.md), [building_note.md](building_note.md)
+ [sign_apk.md](sign_apk.md): `signingConfigs` in Kotlin DSL

## Reference

+ [Migrate your build configuration from Groovy to Kotlin (Android)](https://developer.android.com/build/migrate-to-kotlin-dsl)
+ [Migrate to version catalogs (Android)](https://developer.android.com/build/migrate-to-catalogs)
+ [Gradle: migrating build logic from Groovy to Kotlin](https://docs.gradle.org/current/userguide/migrating_from_groovy_to_kotlin_dsl.html)
