# Android media playback: MediaPlayer, Media3 ExoPlayer, and the RK3566 decode path

Playing audio or video on Android spans the app-level player API down to the SoC's hardware decoder.
Apps choose between two players:

+ **`android.media.MediaPlayer`**: the built-in framework class.
+ **Jetpack Media3 `ExoPlayer`** (`androidx.media3.exoplayer.ExoPlayer`): Google's recommended player for new apps.

Both end up in `MediaCodec`, which on a Rockchip RK3566 board reaches the VPU (video processing unit) through Rockchip's Codec2 components.

## 1. MediaPlayer vs. Media3 ExoPlayer

| | `MediaPlayer` | Media3 `ExoPlayer` |
| --- | --- | --- |
| Ships with | The platform (`android.media`) | Your APK (AndroidX library), updated independently of the OS |
| Model | Strict state machine: e.g. `start()` before `prepare()` / `prepareAsync()` completes is an error | `Player` interface; `prepare()`, `play()`, listeners for state and errors |
| Streaming | Basic HTTP, limited HLS, no DASH | HLS, DASH, SmoothStreaming, RTSP (separate modules) |
| Customization | Little | Custom data sources, renderers, track selection, buffering |
| Media session / system controls | Wire up `MediaSession` yourself | `media3-session`: `MediaSession`, `MediaSessionService`, notification controls |
| Errors | Integer `what`/`extra` codes | `PlaybackException` with error codes, decoder fallback |
| Good for | Short sounds, simple local files | Everything else |

For very short sound effects, `SoundPool` has lower latency than either.

## 2. Decode path on Android 14 / RK3566

```text
+--------------------------------------------------------------------+
| App process                                                        |
|   ExoPlayer: extractor -> MediaCodec (called directly by the app)  |
|   MediaPlayer: thin client -> Binder -> mediaserver                |
+--------------------------------------------------------------------+
            |                                   |
            |                    +-------------------------------+
            |                    | mediaserver: NuPlayer         |
            |                    |   extractor -> MediaCodec     |
            |                    +-------------------------------+
            v                                   v
+--------------------------------------------------------------------+
| Codec2 HAL service (vendor): Rockchip c2.rk.* components           |
|   built on Rockchip MPP (Media Process Platform)                   |
+--------------------------------------------------------------------+
            | kernel driver (Rockchip BSP: mpp_service)
            v
+--------------------------------------------------------------------+
| RK3566 VPU: H.264, H.265/HEVC, VP9 decoders                        |
+--------------------------------------------------------------------+
            | decoded frames (buffers shared, not copied)
            v
   Surface -> SurfaceFlinger -> HWC -> VOP2 display controller (HDMI, MIPI-DSI, eDP, LVDS)
```

1. **Extract (demux)**: the player reads the container and splits it into encoded video and audio packets
   (containers and codecs: [../../Media/video_containers_codecs.md](../../Media/video_containers_codecs.md)).
2. **Decode**: packets go to `MediaCodec`. ExoPlayer calls it from the app process;
   `MediaPlayer` delegates to **NuPlayer** in `mediaserver`, which calls `MediaCodec` there.
3. **Codec2 HAL**: Codec2 is the default codec framework since Android 10 and replaces the deprecated OMX (OpenMAX IL) path.
   Rockchip's components (named `c2.rk.*`, e.g. a `c2.rk.avc.decoder`) drive the VPU through MPP.
4. **Render**:
   + Video: decoded buffers go to a `Surface`. With `SurfaceView`, SurfaceFlinger can hand them to a hardware overlay plane of the display controller without GPU composition.
   + Audio: PCM goes through **AudioFlinger** and the audio HAL to ALSA (HDMI audio, I2S codec, analog out).

Check which decoders the image provides:

```shell
adb shell ls /vendor/etc/ | grep media_codecs          # codec list XML files
adb shell dumpsys media.player | grep -i c2.rk          # codecs known to the media framework
adb logcat | grep -iE "codec2|c2\.rk|mpp"              # which component a playback actually uses
```

In app code, `MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos` lists the same codecs; `isHardwareAccelerated` (API 29+) tells hardware from software decoders.

## 3. RK3566 notes

| Topic | Notes |
| --- | --- |
| Hardware decode | Rockchip lists H.265/HEVC and VP9 up to 4K@60 and H.264 up to 4K@30. Check the RK3566 datasheet and your BSP's codec list for exact limits |
| Hardware encode | Up to 1080p@60 H.264 / H.265 |
| Display outputs | HDMI 2.0, MIPI-DSI, eDP, LVDS; which ones exist depends on the board |
| `SurfaceView` vs. `TextureView` | Prefer **`SurfaceView`** for video: it can use an overlay plane. `TextureView` composites every frame through the GPU, which costs power and frames on the Cortex-A55 / Mali-G52 |
| Several streams | Several 1080p streams can decode at once (multi-camera, signage); a 4K stream uses most of the VPU. Measure on your board |
| Fallback | If a format isn't in the hardware list, `MediaCodec` falls back to a software decoder (`c2.android.*`), which is slow at high resolutions on the A55 cores |

## 4. Minimal Media3 ExoPlayer example

```kotlin
// app/build.gradle.kts: use the current Media3 release
dependencies {
    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")
    // implementation("androidx.media3:media3-exoplayer-hls:1.4.1")   // for HLS streams
}
```

```xml
<!-- res/layout/activity_main.xml: PlayerView uses a SurfaceView by default -->
<androidx.media3.ui.PlayerView xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/player_view"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

```kotlin
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

class MainActivity : AppCompatActivity() {

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        playerView = findViewById(R.id.player_view)
    }

    // Create the player when visible, release it when hidden: the hardware decoder is a shared resource
    override fun onStart() {
        super.onStart()
        player = ExoPlayer.Builder(this).build().also { exo ->
            playerView.player = exo
            exo.setMediaItem(MediaItem.fromUri("https://example.com/video.mp4"))   // or a content:// / file URI, RTSP, HLS
            exo.prepare()
            exo.playWhenReady = true
        }
    }

    override fun onStop() {
        super.onStop()
        playerView.player = null
        player?.release()
        player = null
    }
}
```

+ Network URLs need `<uses-permission android:name="android.permission.INTERNET" />`.
+ Playback that must continue without the activity (music, background audio) belongs in a `MediaSessionService`
  running as a foreground service of type `mediaPlayback` ([app_components.md](app_components.md#12-service)).
+ Releasing the player frees the `MediaCodec` instance. Leaked players block the VPU for other apps.

## Related notes

+ [app_components.md](app_components.md): services and the music player example
+ [android_class_hierarchy.md](android_class_hierarchy.md#4-media3-player): the Media3 `Player` interfaces
+ [activity_views.md](activity_views.md): `SurfaceView` / `TextureView` in a layout
+ [intent_intro.md](intent_intro.md): handing media URIs to other apps
+ [../../Media/video_containers_codecs.md](../../Media/video_containers_codecs.md): containers and codecs

## Reference

+ [Media3 ExoPlayer](https://developer.android.com/media/media3/exoplayer)
+ [Media3 session](https://developer.android.com/media/media3/session/control-playback)
+ [MediaPlayer overview](https://developer.android.com/media/platform/mediaplayer)
+ [Supported media formats](https://developer.android.com/media/platform/supported-formats)
+ [MediaCodec (Android API)](https://developer.android.com/reference/android/media/MediaCodec)
+ [Media framework architecture (AOSP)](https://source.android.com/docs/core/media)
+ Rockchip RK3566 datasheet and the BSP's MPP documentation (from the board vendor)
