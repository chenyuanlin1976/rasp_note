# Activity UI: views, view groups, and Compose

An **Activity** is one screen of an app. It doesn't draw anything itself: it owns a **window**,
and the content of that window is a tree of **`View`** objects (or, with Jetpack Compose, composable functions).
Every widget the user sees or touches (button, text field, image, video surface) is a subclass of `android.view.View`.

## 1. The view hierarchy

In `onCreate()`, the activity sets the root of its window's content with `setContentView()`,
either from an XML layout (`setContentView(R.layout.activity_main)`) or from a View Binding root (`setContentView(binding.root)`).

```text
Activity
└── Window
    └── DecorView (system: status bar insets, action bar)
        └── content (your layout root, a ViewGroup)
            ├── TextView          leaf: draws and handles input
            ├── Button
            └── LinearLayout      branch: arranges children
                ├── ImageView
                └── SurfaceView
```

+ **`View` (leaf)**: a widget that draws itself and handles input: clicks, typing, scrolling.
+ **`ViewGroup` (branch)**: a container that measures and positions its children. Every layout is a `ViewGroup`, and a `ViewGroup` is itself a `View`.
+ Each frame, the tree is **measured**, **laid out**, and **drawn** from the root down.
  Deep nesting makes every pass slower, so keep the tree flat.

Full inheritance chains: [android_class_hierarchy.md](android_class_hierarchy.md#2-views-and-layouts).

## 2. Common widgets

| Widget | Purpose | Key attributes / notes |
| --- | --- | --- |
| `TextView` | Shows text | `android:text`, `android:textSize`, `android:textColor` |
| `EditText` | Text input | `android:hint`, `android:inputType` (`number`, `textPassword`, `textEmailAddress`) |
| `Button` / `MaterialButton` | Triggers an action | `setOnClickListener {}` in code (the XML `android:onClick` attribute is discouraged) |
| `ImageView` | Shows an image or vector drawable | `android:src`, `android:scaleType` (`fitCenter`, `centerCrop`) |
| `CheckBox` / `RadioButton` | Multiple / single choice | Put `RadioButton`s in a `RadioGroup` so only one is checked |
| `Switch` / `MaterialSwitch` | On/off toggle | Settings, hardware state toggles |
| `ProgressBar` | Progress or loading | Determinate (horizontal bar) or indeterminate (spinner) |
| `SurfaceView` / `TextureView` | Separate drawing surface | Video, camera preview, high-frame-rate drawing. Prefer `SurfaceView` for video on embedded boards such as the RK3566 ([mediaPlayer_note.md](mediaPlayer_note.md#3-rk3566-notes)) |

With an AppCompat or Material theme, the inflater replaces `<Button>` with `AppCompatButton` or `MaterialButton` automatically.

## 3. Common layouts (ViewGroups)

| Layout | Arranges children | Use for |
| --- | --- | --- |
| `ConstraintLayout` | By constraints relative to the parent and each other | Complex screens without nesting; the default in Android Studio templates |
| `LinearLayout` | In one row or column (`android:orientation`), optionally weighted | Simple stacks |
| `FrameLayout` | On top of each other | A single child, or overlays (spinner over an image); fragment containers |
| `RecyclerView` | Scrolling list or grid, recycling off-screen item views | Long or dynamic lists (needs an `Adapter`) |

## 4. Accessing views from the activity

### 4.1 XML layout + `findViewById`

```xml
<!-- res/layout/activity_main.xml -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp">

    <TextView
        android:id="@+id/statusText"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="System ready" />

    <Button
        android:id="@+id/actionButton"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Start process" />
</LinearLayout>
```

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val statusText = findViewById<TextView>(R.id.statusText)
        val actionButton = findViewById<Button>(R.id.actionButton)

        actionButton.setOnClickListener {
            statusText.text = "Processing..."
        }
    }
}
```

Views may only be touched from the **main (UI) thread**. Post results from worker threads back with coroutines on `Dispatchers.Main` or `runOnUiThread {}`.
For type-safe access without `findViewById`, use View Binding: [View_binding.md](View_binding.md).

### 4.2 Jetpack Compose

For new UI, Google recommends **Jetpack Compose**: the UI is written as `@Composable` Kotlin functions, with no XML layout and no `View` objects per widget.
The activity calls `setContent { }` instead of `setContentView()`:

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MainScreen() }            // instead of setContentView(R.layout.activity_main)
    }
}

@Composable
fun MainScreen() {
    var status by remember { mutableStateOf("System ready") }

    Column(modifier = Modifier.padding(16.dp)) {
        Text(text = status)
        Button(onClick = { status = "Processing..." }) {
            Text("Start process")
        }
    }
}
```

`setContent`, state, and state hoisting: [compose_intro.md](compose_intro.md).
Views and Compose can be mixed: `ComposeView` puts composables in a view layout, `AndroidView` puts a `View` (e.g. a `PlayerView`) in Compose.

## Related notes

+ [android_class_hierarchy.md](android_class_hierarchy.md): `View` / `ViewGroup` inheritance, `Context`
+ [View_binding.md](View_binding.md): View Binding and Data Binding
+ [app_components.md](app_components.md): the activity lifecycle
+ [app_architecture.md](app_architecture.md): `ViewModel` and UI state
+ [mediaPlayer_note.md](mediaPlayer_note.md): video in a `SurfaceView` / `PlayerView`
+ [compose_intro.md](compose_intro.md): Jetpack Compose, `setContent`, state

## Reference

+ [Layouts in views](https://developer.android.com/develop/ui/views/layout/declaring-layout)
+ [View (Android API)](https://developer.android.com/reference/android/view/View)
+ [Build a responsive UI with ConstraintLayout](https://developer.android.com/develop/ui/views/layout/constraint-layout)
+ [Create dynamic lists with RecyclerView](https://developer.android.com/develop/ui/views/layout/recyclerview)
+ [Jetpack Compose](https://developer.android.com/develop/ui/compose)
+ [State and Jetpack Compose](https://developer.android.com/develop/ui/compose/state)
