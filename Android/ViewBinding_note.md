# Android View Binding

To use Android View Binding (which replaces `findViewById` with a safer, generated binding class),  
follow these steps:

## 1. Enable View Binding in build.gradle (Module-level)

Make sure View Binding is turned on in your app's `build.gradle.kts` file:

```groovy
android {
    ...
    buildFeatures {
        viewBinding = true
    }
}
```

## 2. Refactored MainActivity.kt

Here is the sample code utilizing `ActivityMainBinding`.
(Note: Assumes your layout XML file is named `activity_main.xml`, which generates `ActivityMainBinding`)

```kotlin
package com.auo.demousingaidl

class MainActivity : AppCompatActivity() {
    private val TAG = "AUO_Client"
  
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化 View Binding
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // 使用 binding 存取 UI 元件，省去 findViewById
        binding.btnRed.setOnClickListener {
            /* do something*/
        }
    }
}
```

## Key Changes Summary:

+ Enabled View Binding: Added `buildFeatures { viewBinding = true }` in Gradle.
+ Generated Binding Class: Imported com.auo.demousingaidl.databinding.ActivityMainBinding.
+ Inflate Layout: Replaced `setContentView(R.layout.activity_main)` with:

```kotlin
binding = ActivityMainBinding.inflate(layoutInflater)
setContentView(binding.root)
```

+ Removed `findViewById`:  
  Directly referenced views using their XML IDs converted to camelCase  
  (e.g., `R.id.btn_red` becomes `binding.btnRed`).
