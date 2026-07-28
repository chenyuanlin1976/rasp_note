# class inheritance in android

The androidx namespace comprises the Android Jetpack libraries.  
Like the Support Library, libraries in the androidx namespace ship separately from the Android platform  
and provide backward compatibility across Android releases.

## android.view.View

```java
public class View extends Object implements AccessibilityEventSource, Drawable.Callback, KeyEvent.Callback {};
public class ImageView extends View {};
public class ProgressBar extends View {};
public class TextView extends View implements ViewTreeObserver.OnPreDrawListener {};
```

## android.widget.TextView

```java
public class Button extends TextView {};
public class EditText extends TextView {};
```

## android.widget.ImageView

```java
public class ImageButton extends ImageView {};
```

## android.view.SurfaceView

```java
public class SurfaceView extends View {};
public class VideoView extends SurfaceView implements MediaController.MediaPlayerControl {};
```

## android.view.ViewGroup

```java
public abstract class ViewGroup extends View implements ViewManager, ViewParent {};
public class GridLayout extends ViewGroup {};
public class LinearLayout extends ViewGroup {};
public class RelativeLayout extends ViewGroup {};
```

## android.app.Fragment/ androidx.fragment.app.Fragment

```java
public class Fragment extends Object implements ComponentCallbacks2, View.OnCreateContextMenuListener {}; // it was deprecated in API level 28.
public class Fragment implements ComponentCallbacks, View.OnCreateContextMenuListener, LifecycleOwner, ViewModelStoreOwner, HasDefaultViewModelProviderFactory, SavedStateRegistryOwner, ActivityResultCaller {};
```

## Player in androidx.media3.common

androidx.media3.session.MediaController  
androidx.media3.exoplayer.ExoPlayer  

```java
public interface Player;
public class MediaController implements Player {};
public interface ExoPlayer extends Player {};
```

## Context and this in the Activity class

```java
public abstract class Context extends Object {};
public class ContextWrapper extends Context {};
public class ContextThemeWrapper extends ContextWrapper {};
public class Activity extends ContextThemeWrapper implements ComponentCallbacks2, KeyEvent.Callback, LayoutInflater.Factory2, View.OnCreateContextMenuListener, Window.Callback {};
```

## others

androidx.media3.ui.PlayerView  
android.webkit.WebViewClient  

```java
public abstract class Service extends ContextWrapper implements ComponentCallbacks2 {};
public class ActivityGroup extends Activity {};
public class ActivityManager extends Object {};
public class Dialog extends Object implements DialogInterface, KeyEvent.Callback, View.OnCreateContextMenuListener, Window.Callback {};
public class PlayerView extends FrameLayout implements AdViewProvider {};
public class WebView extends AbsoluteLayout implements ViewGroup.OnHierarchyChangeListener, ViewTreeObserver.OnGlobalFocusChangeListener {};
public class WebViewClient extends Object {};
```
