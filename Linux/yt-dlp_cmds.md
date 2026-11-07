# yt-dlp: download videos and audio

[yt-dlp](https://github.com/yt-dlp/yt-dlp) downloads video and audio from YouTube and many other sites.
It is an actively maintained fork of youtube-dl. Sites change often, so keep it up to date.
Only download content you are allowed to.

## 1. Install and update

The standalone binary needs no Python setup. On a 64-bit ARM board (Raspberry Pi, Jetson) use `yt-dlp_linux_aarch64`
from the [releases page](https://github.com/yt-dlp/yt-dlp/releases):

```shell
chmod +x yt-dlp_linux_aarch64
./yt-dlp_linux_aarch64 --version
./yt-dlp_linux_aarch64 -U            # update the binary in place
sudo apt install ffmpeg              # needed to merge video + audio, cut sections, convert audio
```

To call it as `yt-dlp`, rename it and move it into the `PATH`, e.g. `~/.local/bin/yt-dlp`.
The examples below use `yt-dlp`. Alternatively install it with `pipx install yt-dlp`.
The `yt-dlp` package in distribution repositories is often too old to work with YouTube.

## 2. List and choose formats

YouTube serves high resolutions as **separate** video-only and audio-only streams; yt-dlp downloads both and merges them with ffmpeg.

```shell
yt-dlp -F URL                        # list all formats: ID, extension, resolution, codecs, size
yt-dlp -F URL | grep webm            # filter the list, e.g. only WebM (VP9 video, Opus audio)
yt-dlp -f 315+251 URL                # video format 315 + audio format 251, merged
yt-dlp -f 'bv*+ba/b' URL             # best video + best audio, else best single file (the default)
```

Format IDs are site-specific and not guaranteed to exist for every video. On YouTube, for example,
313 = 2160p VP9, 315 = 2160p60 VP9, 251 = Opus audio (WebM), 140 = AAC audio (M4A). Check `-F` for each video.

Instead of fixed IDs, sort by preference with `-S`; yt-dlp then picks the best match available:

```shell
yt-dlp -S 'res:1080' URL                       # best quality up to 1080p
yt-dlp -S 'vcodec:h264,res:1080,acodec:m4a' URL   # prefer H.264 + AAC up to 1080p (plays everywhere)
yt-dlp --merge-output-format mp4 URL           # merge into MP4 instead of MKV/WebM
```

VP9 and AV1 give smaller files at the same quality; H.264 decodes in hardware on more devices,
see [../Media/video_containers_codecs.md](../Media/video_containers_codecs.md).

## 3. Download part of a video

```shell
yt-dlp -f 313+251 --download-sections '*00:00-03:00' URL      # only the first 3 minutes
yt-dlp --download-sections '*10:15-inf' URL                    # from 10:15 to the end
yt-dlp --download-sections '*1:00-2:00' --download-sections '*5:00-6:00' URL   # two sections, two files
yt-dlp --download-sections 'Intro' URL                         # without '*': chapters whose title matches the regex
```

+ The `*` marks a time range; times are `[HH:]MM:SS` or seconds.
+ ffmpeg must be installed. Cuts land on the nearest keyframe, so a section can start a few seconds early.
  Add `--force-keyframes-at-cuts` for exact cuts, which re-encodes and is much slower.

## 4. Audio only

```shell
yt-dlp -f 251 URL                                  # original Opus audio stream, no conversion
yt-dlp -x --audio-format mp3 --audio-quality 0 URL # extract and convert to MP3 (best VBR quality)
```

Converting to MP3 is a lossy re-encode; keep the original stream (`-x` without `--audio-format`) if quality matters.

## 5. Output names, subtitles, playlists

```shell
yt-dlp -o '%(title)s [%(id)s].%(ext)s' URL       # output template (this is the default)
yt-dlp -P ~/Videos URL                           # download directory
yt-dlp --list-subs URL                           # available subtitles
yt-dlp --write-subs --sub-langs 'en.*,zh.*' --embed-subs URL   # download and embed subtitles
yt-dlp --write-auto-subs --sub-langs en URL      # automatic (generated) subtitles
yt-dlp --embed-metadata --embed-thumbnail URL    # title, chapters and cover in the file
yt-dlp -I 1:5 PLAYLIST_URL                       # only items 1 to 5 of a playlist
yt-dlp --download-archive done.txt PLAYLIST_URL  # skip videos already downloaded (IDs recorded in done.txt)
yt-dlp -r 2M URL                                 # limit the speed to 2 MB/s
```

## 6. Troubleshooting

| Problem | Fix |
| --- | --- |
| "Requested format is not available", HTTP 403, or extraction errors | Update yt-dlp (`-U`); site changes break older versions |
| Separate video and audio files instead of one | Install ffmpeg |
| "Sign in to confirm your age" or members-only videos | `--cookies-from-browser firefox` (or `chrome`), using a browser where you are signed in |
| Video won't play on a TV or phone | Choose H.264 + AAC (`-S 'vcodec:h264,acodec:m4a'`) or re-encode with ffmpeg |

## Related notes

+ [ffmpeg_cmds.md](ffmpeg_cmds.md): cut, convert and encode the downloaded files
+ [wget_cmds.md](wget_cmds.md): downloading ordinary files over HTTP
+ [../Media/video_containers_codecs.md](../Media/video_containers_codecs.md): containers and codecs (MP4/WebM, H.264/VP9/AV1)

## Reference

+ [yt-dlp README: options, format selection, output template](https://github.com/yt-dlp/yt-dlp#readme)
+ [yt-dlp releases](https://github.com/yt-dlp/yt-dlp/releases)
