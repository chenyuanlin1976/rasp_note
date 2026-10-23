# compare Groovy and Kotlin DSL

To compare the two clearly,  
let's look at how the exact same configuration blocks are written side-by-side  
in Groovy (`build.gradle`) versus Kotlin DSL (`build.gradle.kts`).

## Side-by-Side Syntax Comparison

| Feature/ Element     | Groovy (build.gradle)                                       | Kotlin DSL (build.gradle.kts)                                |
| -------------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| File Extension       | `.gradle`                                                   | `.gradle.kts`                                                |
| Assigning Properties | Space-separated (`compileSdk 34`)                           | Uses `=` operator (`compileSdk = 34`)                        |
| String Quotes        | Double or single quotes work (`"text" or 'text'`)           | Strict: Double quotes only (`"text"`)                        |
| Function Calls       | Parentheses optional (implementation 'com.example:lib:1.0') | Parentheses required (implementation("com.example:lib:1.0")) |
| Plugin Block         | plugins { id 'com.android.application' }                    | plugins { id("com.android.application") }                    |

## Detailed Code Examples

### 1. The android {} Configuration Block

Notice how Kotlin DSL requires the `=` sign for assigning numbers and strings, and uses proper string quotes.

```groovy
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.example.app"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }
}
```

```kotlin
android {
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
}
```

### 2. Dependencies Block

In Groovy, dependencies use method calls where parentheses and single quotes are standard.  
In Kotlin DSL, it looks like standard Kotlin function calls with double quotes.

```groovy
dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    testImplementation 'junit:junit:4.13.2'
}
```

```kotlin
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    testImplementation("junit:junit:4.13.2")
}
```

### 3. Build Types and ProGuard

Setting boolean flags (like isMinifyEnabled) also requires the = operator in Kotlin DSL.

```groovy
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

```kotlin
buildTypes {
    getByName("release") {
        isMinifyEnabled = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```
