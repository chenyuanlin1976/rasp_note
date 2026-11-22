# Jetpack Compose: declarative UI, setContent, state, and state hoisting

**Jetpack Compose** is Android's declarative UI toolkit. The UI is written in Kotlin as functions annotated with `@Composable`,
with no XML layouts and no `View` object per widget.
Google recommends it for new UI; the View system (XML layouts) is still supported, and both can be mixed in one app.

## 1. Declarative vs. imperative

| | Views + XML (imperative) | Compose (declarative) |
| --- | --- | --- |
| UI defined in | XML layout, inflated into a `View` tree | `@Composable` Kotlin functions |
| Updating the UI | Find the view (`findViewById`, View Binding) and change it: `textView.text = "Hello"`, `button.isEnabled = false` | Change the **state**; Compose re-runs (**recomposes**) the functions that read it |
| Lists | `RecyclerView` + `Adapter` + `ViewHolder` | `LazyColumn { items(list) { ... } }` |
| Source of truth | Data and widgets both hold values, which can drift apart | State only; the UI is a function of the state |

The same screen both ways:

```xml
<!-- res/layout/activity_main.xml -->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:padding="16dp">

    <TextView
        android:id="@+id/greetingText"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Hello, World!" />
</LinearLayout>
```

```kotlin
// Views: inflate the layout, then mutate the widget
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        findViewById<TextView>(R.id.greetingText).text = "Hello, Kotlin!"
    }
}
```

```kotlin
// Compose: describe the UI for the given input
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            GreetingCard(name = "Kotlin")
        }
    }
}

@Composable
fun GreetingCard(name: String) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text(text = "Hello, $name!")
    }
}
```

## 2. `setContent`: from the activity to Compose

An activity hands its window to Compose with `setContent { }` instead of `setContentView()`:

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {                    // a new project uses its generated theme, e.g. MyAppTheme { }
                Surface {
                    CounterScreen()            // section 4
                }
            }
        }
    }
}
```

+ **`setContent` is an extension function** on `androidx.activity.ComponentActivity`
  (`fun ComponentActivity.setContent(parent: CompositionContext? = null, content: @Composable () -> Unit)`),
  from the `androidx.activity:activity-compose` library.
  That's why it can be called inside `MainActivity` like a member, and why it must be imported.
  Extension functions in general: [../../DevTools/kotlin_extension_functions.md](../../DevTools/kotlin_extension_functions.md).
+ **Which activity class**: `ComponentActivity` or a subclass (`FragmentActivity`, `AppCompatActivity`). A plain `android.app.Activity` doesn't have it.
+ **Trailing lambda**: `content` is the last parameter, so `setContent { ... }` is the same as `setContent(content = { ... })`.
  The lambda is `@Composable`, so composables can be called directly in it; it becomes the root of the Compose UI tree.
+ **Theme and root container**: wrap the screen in the app theme and a `Surface` (or `Scaffold`), so colors, typography and the background apply everywhere.
+ **Naming**: composables that emit UI are named in PascalCase (`GreetingCard`), like classes.
+ A function that calls composables must itself be `@Composable`; calling one from normal code is a compile error.

## 3. Building blocks

| Kind | Examples | Notes |
| --- | --- | --- |
| Basic elements | `Text`, `Button`, `Image`, `Icon`, `TextField` | Material 3 versions in `androidx.compose.material3` |
| Layouts | `Column`, `Row`, `Box` | Vertical, horizontal, stacked |
| Lazy lists | `LazyColumn`, `LazyRow`, `LazyVerticalGrid` | Compose only the visible items; replace `RecyclerView` |
| Modifiers | `Modifier.fillMaxWidth().padding(8.dp).clickable { }` | Size, padding, input, drawing. **Order matters**: padding before `clickable` shrinks the click area |
| State | `remember { mutableStateOf(0) }` | Section 4 |
| Preview | `@Preview` on a composable without parameters | Rendered in Android Studio without running the app |

Why use it:

+ **Less code**: no XML, no `findViewById`, no adapters for lists, simple custom components.
+ **Kotlin all the way**: lambdas, coroutines, type safety and extension functions inside UI code.
+ **Recomposition**: when state changes, Compose re-runs only the composables that read it,
  and skips children whose (stable) parameters haven't changed.
+ **Interoperability**: `ComposeView` puts composables into a View layout or fragment;
  `AndroidView` puts a `View` (e.g. a `PlayerView` or a map) into Compose.

## 4. State

### 4.1 `mutableStateOf`: observable state

A plain variable (`var count = 0`) isn't tracked: changing it doesn't update the UI.
`mutableStateOf(initial)` returns a `MutableState<T>` whose `.value` Compose **observes**:

+ When a composable reads `.value` during composition, Compose records that the composable depends on this state.
+ When `.value` changes, Compose schedules recomposition of every composable that read it.

For primitives, `mutableIntStateOf`, `mutableLongStateOf`, `mutableFloatStateOf` avoid boxing.
Collections need observable types (`mutableStateListOf()`), or replace the whole list in a `mutableStateOf`;
mutating an ordinary `MutableList` in place isn't seen.

### 4.2 `remember`: surviving recomposition

A composable can run many times. Without `remember`, `val count = mutableStateOf(0)` creates a new state, back at 0, on every recomposition.
`remember { }` stores the value in the composition the first time and returns the same object afterwards:

```kotlin
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun CounterButton() {
    // `by` delegation: read and write `count` instead of `countState.value`
    var count by remember { mutableIntStateOf(0) }

    Column(modifier = Modifier.padding(16.dp)) {
        Text(text = "Clicked $count times")
        Button(onClick = { count++ }) {
            Text("Increment")
        }
    }
}
```

+ `by` needs the `getValue` / `setValue` imports (or `import androidx.compose.runtime.*`).
+ `remember` survives recomposition, **not** activity re-creation (rotation, other configuration changes):
  + `rememberSaveable { }` stores the value in the saved instance state `Bundle`, so it also survives re-creation and process death. Only for small, `Bundle`-saveable values.
  + Screen and business state belongs in a `ViewModel` ([app_architecture.md](app_architecture.md)).
+ A value left in the composition is forgotten when the composable leaves it (e.g. an `if` turns false).

## 5. State hoisting

**State hoisting** moves state out of a composable into its caller: the caller passes the **value** down and **event callbacks** up.
This is "state flows down, events flow up" (unidirectional data flow).

```kotlin
@Composable
fun CounterScreen() {
    var count by remember { mutableIntStateOf(0) }

    StatelessCounter(
        count = count,
        onIncrement = { count++ },
        onReset = { count = 0 }
    )
}

@Composable
fun StatelessCounter(
    count: Int,
    onIncrement: () -> Unit,
    onReset: () -> Unit,
    modifier: Modifier = Modifier          // convention: first optional parameter, passed to the root
) {
    Column(modifier = modifier.padding(16.dp)) {
        Text(text = "Count: $count")
        Button(onClick = onIncrement) { Text("Add 1") }
        Button(onClick = onReset) { Text("Reset") }
    }
}
```

+ **Single source of truth**: siblings read the same state instead of keeping copies.
+ **Reuse**: `StatelessCounter` owns no data, so it works on any screen and in `@Preview`.
+ **Testing**: pass sample values and check that the callbacks are called.
+ The callbacks are ordinary lambdas (`() -> Unit`), not `@Composable`.

### 5.1 Where state should live

| Where | Good for | Survives rotation? | Survives process death? |
| --- | --- | --- | --- |
| `remember { mutableStateOf() }` in the composable | UI-only details: expanded/collapsed, a text field's focus | No | No |
| `rememberSaveable { }` | Small UI values the user would miss: typed text, selected tab | Yes | Yes |
| Hoisted to a parent composable | State shared by siblings | Like the parent's storage | Like the parent's storage |
| `ViewModel` exposing `StateFlow` | Screen and business state, data from network or database | Yes | No (use `SavedStateHandle` for the key values) |

Reading a `ViewModel`'s `StateFlow` in Compose:

```kotlin
@Composable
fun CounterRoute(viewModel: CounterViewModel = viewModel()) {
    val count by viewModel.count.collectAsStateWithLifecycle()   // lifecycle-runtime-compose
    StatelessCounter(count = count, onIncrement = viewModel::increment, onReset = viewModel::reset)
}
```

## Related notes

+ [activity_views.md](activity_views.md): the View system, which Compose replaces for new UI
+ [View_binding.md](View_binding.md): typed view access for XML layouts
+ [app_architecture.md](app_architecture.md): UI layer, `ViewModel`, unidirectional data flow
+ [../../DevTools/kotlin_extension_functions.md](../../DevTools/kotlin_extension_functions.md): extension functions and lambdas with receivers

## Reference

+ [Jetpack Compose](https://developer.android.com/develop/ui/compose)
+ [Thinking in Compose](https://developer.android.com/develop/ui/compose/mental-model)
+ [State and Jetpack Compose](https://developer.android.com/develop/ui/compose/state)
+ [Where to hoist state](https://developer.android.com/develop/ui/compose/state-hoisting)
+ [Compose modifiers](https://developer.android.com/develop/ui/compose/modifiers)
+ [Compose and other libraries](https://developer.android.com/develop/ui/compose/libraries)
+ [Interoperability APIs](https://developer.android.com/develop/ui/compose/migrate/interoperability-apis)
