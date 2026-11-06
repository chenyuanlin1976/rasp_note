# Android class hierarchy: Context, components, views

This note shows the inheritance chains of the Android classes that apps use most: `Context` and the app components, views and layouts, fragments, and the Media3 player.
Knowing the chain explains everyday code, for example why `this` works as a `Context` inside an `Activity`, or why a `Button` has every `TextView` method.

Platform classes are in the `android.*` packages and ship with the OS.
Jetpack (AndroidX) classes are in `androidx.*`. They ship inside your APK, are updated independently of the platform, and work the same on older Android versions.
Prefer the AndroidX class when both exist (`Fragment`, `AppCompatActivity`).

## 1. Context and app components

```text
java.lang.Object
└── android.content.Context                              (abstract)
    └── android.content.ContextWrapper                   delegates every call to a base Context
        ├── android.app.Application
        ├── android.app.Service                          (abstract)
        └── android.view.ContextThemeWrapper             adds a theme
            └── android.app.Activity
                └── androidx.core.app.ComponentActivity
                    └── androidx.activity.ComponentActivity      Lifecycle, ViewModel, SavedState, Activity Result API, back handling
                        └── androidx.fragment.app.FragmentActivity   hosts AndroidX fragments
                            └── androidx.appcompat.app.AppCompatActivity   AppCompat themes, action bar, AppCompat widgets
```

```java
public abstract class Context { }
public class ContextWrapper extends Context { }
public class ContextThemeWrapper extends ContextWrapper { }
public class Activity extends ContextThemeWrapper
        implements LayoutInflater.Factory2, Window.Callback, KeyEvent.Callback,
                   View.OnCreateContextMenuListener, ComponentCallbacks2 { }
public abstract class Service extends ContextWrapper implements ComponentCallbacks2 { }
public class Application extends ContextWrapper implements ComponentCallbacks2 { }
```

Because `Activity`, `Service` and `Application` are all `Context`s, `this` can be passed wherever a `Context` is needed:

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Toast.makeText(this, "Hello", Toast.LENGTH_SHORT).show()   // this = Activity = Context
    }
}
```

Which `Context` to use:

| Context | Lifetime | Use for |
| --- | --- | --- |
| `Activity` (`this`) | The screen | Anything UI: inflating views, dialogs, themed resources, starting activities |
| `applicationContext` | The process | Long-lived objects (singletons, databases, repositories) |
| `Service` (`this`) | The service | Work inside the service |

Keeping an `Activity` in a long-lived object leaks the whole screen after rotation or `finish()`. Use `applicationContext` there.

Other classes from the old note, for comparison:

+ `Dialog` is **not** a `Context`. It takes one in its constructor and implements `Window.Callback` and `KeyEvent.Callback` like `Activity`.
+ `ActivityManager` is a system service class (`getSystemService(ActivityManager::class.java)`), not part of this hierarchy.
+ `ActivityGroup` (extends `Activity`) is deprecated since API 13. Use fragments instead.

## 2. Views and layouts

Every widget is a `View`. A `ViewGroup` is a `View` that contains other views, and every layout is a `ViewGroup`.

```text
android.view.View
├── android.widget.TextView
│   ├── android.widget.Button
│   │   └── android.widget.CompoundButton                (abstract)
│   │       ├── android.widget.CheckBox
│   │       ├── android.widget.RadioButton
│   │       └── android.widget.Switch
│   └── android.widget.EditText
├── android.widget.ImageView
│   └── android.widget.ImageButton
├── android.widget.ProgressBar
├── android.view.SurfaceView
│   └── android.widget.VideoView
└── android.view.ViewGroup                               (abstract)
    ├── android.widget.LinearLayout
    ├── android.widget.RelativeLayout
    ├── android.widget.GridLayout
    ├── android.widget.FrameLayout
    │   ├── android.widget.ScrollView
    │   └── androidx.media3.ui.PlayerView
    ├── android.widget.AbsoluteLayout                    (deprecated)
    │   └── android.webkit.WebView
    ├── androidx.constraintlayout.widget.ConstraintLayout
    └── androidx.recyclerview.widget.RecyclerView
```

```java
public class View implements Drawable.Callback, KeyEvent.Callback, AccessibilityEventSource { }
public class TextView extends View implements ViewTreeObserver.OnPreDrawListener { }
public class Button extends TextView { }
public class EditText extends TextView { }
public class ImageView extends View { }
public class ImageButton extends ImageView { }
public class SurfaceView extends View { }
public class VideoView extends SurfaceView implements MediaController.MediaPlayerControl { }
public abstract class ViewGroup extends View implements ViewParent, ViewManager { }
public class WebView extends AbsoluteLayout
        implements ViewTreeObserver.OnGlobalFocusChangeListener, ViewGroup.OnHierarchyChangeListener { }
```

+ `Button` is a `TextView` with a button background, so `setText()`, `textSize` and `drawableStart` all work on it.
+ `ImageButton` is an `ImageView`, so it shows an image (`src`), not text.
+ `SurfaceView` (and `VideoView`) render on a separate surface, which is efficient for video and camera previews.
+ `WebViewClient` is not a view. It is a callback class (`extends Object`) that you attach with `webView.webViewClient = ...` to handle page loading.

**AppCompat widgets.** In an `AppCompatActivity`, the layout inflater replaces `<Button>` with `AppCompatButton` (a subclass of `Button`), `<TextView>` with `AppCompatTextView`, and so on.
They add tinting and backported features. With a Material theme, `<Button>` becomes `MaterialButton` (extends `AppCompatButton`).

## 3. Fragments

| Class | Status | Extends / implements |
| --- | --- | --- |
| `android.app.Fragment` | Deprecated in API 28 | `Object`, `ComponentCallbacks2`, `View.OnCreateContextMenuListener` |
| `androidx.fragment.app.Fragment` | Use this one | `Object`, `LifecycleOwner`, `ViewModelStoreOwner`, `SavedStateRegistryOwner`, `ActivityResultCaller`, ... |

A `Fragment` is **not** a `Context` and not a `View`. Use `requireContext()` to get one, and inflate its UI in `onCreateView()`.
AndroidX fragments need a `FragmentActivity` (or `AppCompatActivity`) as host; see [View_binding.md](View_binding.md) (section 1.4).

## 4. Media3 `Player`

`Player` is an interface. Both the local player and the remote controller implement it, so UI code such as `PlayerView` works with either.

```text
androidx.media3.common.Player                         (interface)
├── androidx.media3.exoplayer.ExoPlayer               (interface; ExoPlayer.Builder(context).build() creates it)
└── androidx.media3.session.MediaController           controls a player in a MediaSessionService
```

```java
public interface Player { }
public interface ExoPlayer extends Player { }
public class MediaController implements Player { }
```

```kotlin
val player: Player = ExoPlayer.Builder(context).build()
playerView.player = player        // PlayerView only needs the Player interface
```

## 5. Comments

+ **Code to the most general type you need.** Take a `Context`, not an `Activity`, and a `Player`, not an `ExoPlayer`. Then the code works with more callers and is easier to test.
+ **Know which object is a `Context`.** `Activity`, `Service` and `Application` are. `Fragment`, `View`, `Dialog` and `ViewModel` are not, though `View.context` and `requireContext()` give you one. Never keep an `Activity` in a `ViewModel` or singleton.
+ **Prefer AndroidX over the platform class.** It's updated with your app instead of with the OS, so behavior is the same on every Android version.
+ **Composition beats deep inheritance in your own code.** Android's own trees are deep for historical reasons. Jetpack Compose doesn't use a `View` hierarchy at all: UI is built from composable functions, not subclasses.
+ **Look it up rather than memorize it.** Every class page on developer.android.com starts with its full inheritance chain and "Known direct subclasses". In Android Studio, Ctrl+H (Type Hierarchy) shows it too.

## Related notes

+ [View_binding.md](View_binding.md): activities and fragments with View Binding
+ [AndroidManifest.md](AndroidManifest.md): declaring activities, services and the application class
+ [AIDL_binding.md](AIDL_binding.md): binding an `Activity` to a `Service`
+ [app_project_structure.md](app_project_structure.md), [mediaPlayer_note.md](mediaPlayer_note.md)

## Reference

+ [Context (Android API)](https://developer.android.com/reference/android/content/Context)
+ [Activity (Android API)](https://developer.android.com/reference/android/app/Activity)
+ [View (Android API)](https://developer.android.com/reference/android/view/View)
+ [AndroidX overview (Android)](https://developer.android.com/jetpack/androidx)
+ [Fragments (Android)](https://developer.android.com/guide/fragments)
+ [Media3 Player (Android)](https://developer.android.com/media/media3/exoplayer)
