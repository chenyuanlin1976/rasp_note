# View Binding and Data Binding (XML layouts)

With XML layouts, the code must get references to the views (`TextView`, `Button`, ...) and push data into them.

+ **`findViewById()`**: looks views up by ID at run time. It isn't type-checked and returns `null` for an ID from the wrong layout.
+ **View Binding**: the build generates a class per layout with typed fields for every view that has an ID. It is the default replacement for `findViewById()`.
+ **Data Binding**: like View Binding, plus binding expressions in the XML (`@{user.name}`), observable data, and two-way binding.

For new UI, Google recommends **Jetpack Compose**, which has no XML layouts and needs neither library.
These notes are for view-based code.

## 1. View Binding

### 1.1 Enable

```kotlin
// app/build.gradle.kts
android {
    buildFeatures {
        viewBinding = true
    }
}
```

The old form `viewBinding { enabled = true }` is deprecated.
To skip a layout, add `tools:viewBindingIgnore="true"` to its root view.

### 1.2 Generated class

`res/layout/activity_main.xml` → `<namespace>.databinding.ActivityMainBinding`.
View IDs become camelCase fields: `@+id/btn_red` → `binding.btnRed`.

```xml
<!-- res/layout/activity_main.xml -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <TextView
        android:id="@+id/status_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />

    <Button
        android:id="@+id/btn_red"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Red" />
</LinearLayout>
```

### 1.3 Activity

```kotlin
package com.example.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)          // instead of setContentView(R.layout.activity_main)

        binding.btnRed.setOnClickListener {
            binding.statusText.text = "Red pressed"
        }
    }
}
```

### 1.4 Fragment

A fragment's view can be destroyed while the fragment lives on, so release the binding in `onDestroyView()`:

```kotlin
class StatusFragment : Fragment() {

    private var _binding: FragmentStatusBinding? = null
    private val binding get() = _binding!!   // valid only between onCreateView and onDestroyView

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentStatusBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null                        // avoid leaking the view hierarchy
    }
}
```

### 1.5 What it guarantees

+ **Type safety**: each field has the view's real type, so no casts and no `ClassCastException`.
+ **Null safety**: fields are non-null, except for a view that exists only in some configurations of the layout
  (for example only in `layout-land/`). That field is `@Nullable`.
+ Mismatches between layout and code fail at **compile time**.

## 2. Data Binding

### 2.1 Enable

```kotlin
// app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.kapt")          // data binding runs an annotation processor
}

android {
    buildFeatures {
        dataBinding = true
    }
}
```

### 2.2 Layout with variables

The layout's root is `<layout>`, with a `<data>` section for variables:

```xml
<layout xmlns:android="http://schemas.android.com/apk/res/android">
    <data>
        <variable
            name="vm"
            type="com.example.app.StatusViewModel" />
    </data>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical">

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="@{vm.status}" />              <!-- one-way: LiveData<String> -> view -->

        <EditText
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="@={vm.name}" />               <!-- two-way: MutableLiveData<String> <-> view -->
    </LinearLayout>
</layout>
```

### 2.3 Activity

```kotlin
class MainActivity : AppCompatActivity() {

    private val vm: StatusViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivityMainBinding.inflate(layoutInflater)
        binding.vm = vm
        binding.lifecycleOwner = this    // required, or LiveData changes won't update the views
        setContentView(binding.root)
    }
}
```

## 3. Comparison

| | `findViewById` | View Binding | Data Binding |
| --- | --- | --- | --- |
| Setup | None | `buildFeatures.viewBinding = true` | `buildFeatures.dataBinding = true` + kapt |
| Layout XML | Unchanged | Unchanged | Root `<layout>` + `<data>` |
| Type / null safety | No | Yes (compile time) | Yes |
| Expressions in XML, two-way binding | No | No | Yes (`@{}`, `@={}`) |
| Build cost | None | Small (no annotation processing) | Higher (annotation processing) |
| Use for | Old code | Most view-based code | Existing MVVM code that already uses it |

## Related notes

+ [Groovy_kotlin_DSL.md](Groovy_kotlin_DSL.md): `build.gradle(.kts)` syntax
+ [../IPC/AIDL_app_bound_svc.md](../IPC/AIDL_app_bound_svc.md): a different "binding", binding to a service

## Reference

+ [View binding](https://developer.android.com/topic/libraries/view-binding)
+ [Data binding library](https://developer.android.com/topic/libraries/data-binding)
+ [Two-way data binding](https://developer.android.com/topic/libraries/data-binding/two-way)
+ [Jetpack Compose](https://developer.android.com/develop/ui/compose)
