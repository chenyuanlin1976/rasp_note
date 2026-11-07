# ffmpeg: cut videos, extract frames, build videos from images

`ffmpeg` converts, cuts, and filters audio and video from the command line.
Its general form is `ffmpeg [input options] -i input [output options] output`:
an option applies to the file that **follows** it, so the position of `-ss`, `-t`, and `-to` matters.

```shell
ffmpeg -h                  # basic help (-h long / -h full for more)
ffmpeg -encoders           # available encoders (-decoders, -codecs, -filters)
ffprobe input.mp4          # show streams, codecs, duration, resolution
```

## 1. Common options

| Option | Meaning |
| --- | --- |
| `-i FILE` | Input file |
| `-ss TIME` | Start position. Before `-i`: fast seek in the input. After `-i`: decode and discard up to that point (slow, exact) |
| `-to TIME` | Stop position |
| `-t DURATION` | Duration to read or write |
| `-c copy` | Copy streams without re-encoding (fast, no quality loss). `-c:v`/`-c:a` set video/audio separately; `-vcodec`/`-acodec` are old names for the same |
| `-c:v libx264` | Encode video as H.264 (`-crf 18`–`28` sets quality: lower = better and bigger, default 23) |
| `-vf FILTER` | Video filter chain (`scale=...`, `fps=...`) |
| `-s WxH` | Output frame size (prefer `-vf scale`, which can keep the aspect ratio) |
| `-an`, `-vn` | Drop audio / video |
| `-y` | Overwrite the output without asking |

Times are `HH:MM:SS[.ms]` or seconds (`90`, `1.5`).

## 2. Cut a video

```shell
ffmpeg -ss 00:00:30 -t 00:00:10 -i input.mp4 -c copy output.mp4      # 10 s from 0:30
ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 -c copy output.mp4     # 1:00 to 2:00
ffmpeg -ss 00:28:16 -i test.mp4 -c copy test_new.mp4                 # from 28:16 to the end
```

+ With `-c copy`, ffmpeg can only cut at **keyframes**. The cut starts at the keyframe before `-ss`,
  so the clip may start a few seconds early, or with a frozen/black picture until the next keyframe.
+ For a frame-accurate cut, **re-encode** (slower):

  ```shell
  ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 -c:v libx264 -crf 20 -c:a aac output.mp4
  ```

+ Here `-ss` and `-to` both come before `-i`, so they're both positions in the input.
  If `-to` is put **after** `-i` while `-ss` is before it, the timestamps restart at 0 and `-to` acts like `-t` (a duration).

Cut and scale at the same time:

```shell
ffmpeg -ss 00:01:00 -to 00:02:00 -i input.mp4 -vf scale=1920:-2 output.mp4   # width 1920, height keeps the aspect ratio (even)
```

## 3. Extract frames as images

```shell
ffmpeg -i input.mp4 frame%04d.png                                  # every frame: frame0001.png, frame0002.png, ...
ffmpeg -i input.mp4 -vf fps=10 frame%04d.png                       # 10 frames per second of video
ffmpeg -i input.mp4 -vf fps=1/5 frame%04d.png                      # one frame every 5 s
ffmpeg -ss 00:01:00 -i input.mp4 -frames:v 1 output.png            # one frame at 1:00
ffmpeg -ss 00:00:05 -to 00:00:08 -i input.mp4 frame%04d.png        # all frames between 0:05 and 0:08
```

+ `%04d` is a 4-digit counter with leading zeros.
+ Use `.jpg` instead of `.png` for smaller files (`-q:v 2` = high JPEG quality, range 2–31).
+ `-r 1/5` as an output option also works for "one frame every 5 s", but the `fps` filter is clearer.

## 4. Build a video from images

```shell
ffmpeg -framerate 60 -i image%03d.png -c:v libx264 -pix_fmt yuv420p output.mp4
```

| Part | Meaning |
| --- | --- |
| `-framerate 60` | Input option: read the images as 60 per second (the output keeps that rate). Lower values make each image stay longer |
| `-i image%03d.png` | Image sequence `image001.png`, `image002.png`, ... (`%03d` = 3-digit counter). It must start near 1; otherwise add `-start_number N` |
| `-c:v libx264` | Encode as H.264, which almost every player supports |
| `-pix_fmt yuv420p` | YUV 4:2:0 pixel format. Without it, PNG input may give 4:4:4, which many players can't play |

+ H.264 with `yuv420p` needs an **even width and height**. For odd-sized images, add `-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"`.
+ Files that aren't numbered in sequence: `-pattern_type glob -i '*.png'` (sorted by name).

### 4.1 Single image to video

```shell
ffmpeg -loop 1 -i image.png -c:v libx264 -tune stillimage -t 10 -pix_fmt yuv420p output.mp4   # 10 s video
```

`-loop 1` repeats the image endlessly, so `-t` is required to stop it.

### 4.2 Resize

```shell
ffmpeg -framerate 25 -i image%03d.png -vf scale=1280:720 -c:v libx264 -pix_fmt yuv420p output.mp4
```

`scale=1280:-2` sets the width and computes an even height that keeps the aspect ratio.

### 4.3 Add audio

```shell
ffmpeg -framerate 25 -i image%03d.png -i audio.mp3 -c:v libx264 -c:a aac -pix_fmt yuv420p -shortest output.mp4
```

The second `-i` adds the audio file. `-shortest` ends the output when the shorter input ends.
`-c:a aac` re-encodes the audio for MP4; `-c:a copy` keeps MP3 as is (MP4 can contain MP3, but AAC is more compatible).

## Related notes

+ [yt-dlp_cmds.md](yt-dlp_cmds.md): downloading videos; yt-dlp uses ffmpeg to merge and convert
+ [../orangePi.md](../orangePi.md): hardware decoders on the Orange Pi (`ffmpeg -decoders`)

## Reference

+ [ffmpeg documentation](https://ffmpeg.org/ffmpeg.html)
+ [ffmpeg filters (scale, fps)](https://ffmpeg.org/ffmpeg-filters.html)
+ [FFmpeg wiki: Seeking](https://trac.ffmpeg.org/wiki/Seeking)
+ [FFmpeg wiki: H.264 encoding guide](https://trac.ffmpeg.org/wiki/Encode/H.264)
