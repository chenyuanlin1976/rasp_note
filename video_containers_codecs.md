# Video containers and codecs

A video file has two layers. The **container** (e.g. `.mp4`) is the file format: it packs video, audio, subtitles and metadata
into one file. A **codec** (e.g. H.264) is how each stream inside it is compressed.
The file extension only names the container, so two `.mp4` files can need different decoders.
Use `ffprobe file.mp4` to see which codecs a file actually contains.

## 1. Containers

| Container | Extension | Typical video codecs | Notes |
| --- | --- | --- | --- |
| MP4 (MPEG-4 Part 14) | `.mp4`, `.m4v` | H.264, H.265, AV1 | The most compatible choice: browsers, phones, TVs |
| QuickTime | `.mov` | H.264, H.265, ProRes | Apple's format; MP4 is derived from it. Quality depends on the codec, not the container |
| Matroska | `.mkv` | Almost anything | Open, very flexible: many audio/subtitle tracks, chapters. Less supported on TVs, browsers and editors |
| WebM | `.webm` | VP8, VP9, AV1 | A restricted Matroska for the web, with Vorbis or Opus audio |
| AVI | `.avi` | Older codecs (MPEG-4 Part 2, MJPEG) | Old Microsoft format; poorly suited to modern codecs. Avoid for new files |
| MPEG-TS | `.ts`, `.m2ts` | H.264, H.265, MPEG-2 | Broadcast, HLS streaming, Blu-ray; survives cut-off or damaged data |

Changing only the container (**remuxing**) is fast and lossless if the new container supports the codecs:
`ffmpeg -i in.mkv -c copy out.mp4`.

## 2. How video compression works

A codec standard (H.264, AV1, ...) defines the compressed bitstream and how to decode it.
Encoders are separate implementations, e.g. `libx264` (software) or a GPU's hardware encoder, which differ in speed and quality.
Most delivery codecs are **lossy**: they discard information the eye is unlikely to notice.

+ **Intra-frame** compression compresses each frame on its own, much like JPEG.
+ **Inter-frame** compression stores only what changed relative to other frames, using motion vectors.
+ Frame types:
  + **I-frame (keyframe)**: self-contained, intra-coded only. Decoding and seeking can start here.
  + **P-frame**: predicted from earlier frames.
  + **B-frame**: predicted from both earlier and later frames; smallest.
+ A **GOP** (group of pictures) is the run of frames from one keyframe to the next.
  This is why cutting with `ffmpeg -c copy` can only start cleanly at a keyframe.
+ **Chroma subsampling**: frames are stored as Y'CbCr, usually 4:2:0 (color at half the resolution in both directions),
  see [color_spaces_linearity.md](color_spaces_linearity.md).
+ **Intra-only** codecs (ProRes, DNxHD/DNxHR, MJPEG) use only intra-frame compression: much larger files,
  but every frame decodes independently, which makes editing and scrubbing fast.

## 3. Delivery codecs compared

| Codec | Year | Efficiency (rough, same quality) | Licensing | Hardware decoding | Where it's used |
| --- | --- | --- | --- | --- | --- |
| H.264 / AVC | 2003 | Baseline | Patent pool, royalties | Practically everywhere | Web video, Blu-ray, broadcast, cameras, video calls |
| H.265 / HEVC | 2013 | Up to ~50% smaller than H.264 | Several patent pools, complex | Most devices since about 2016 | 4K/HDR streaming, UHD Blu-ray, Apple devices, phones, cameras |
| VP9 | 2013 | Similar to HEVC | Royalty-free (Google) | Most Android phones, PC GPUs; Apple only recently | YouTube, WebM |
| AV1 | 2018 | Roughly 20–30% smaller than HEVC/VP9 | Royalty-free (AOMedia) | Newer devices only (about 2020 onward) | YouTube, Netflix, browsers, video calls |

Efficiency figures vary with content, resolution and encoder settings; treat them as rough guides.

### 3.1 H.264 (AVC)

Also called MPEG-4 Part 10. The most widely used codec, decoded in hardware by nearly every device.

+ Pros: maximum compatibility; fast encoding and decoding; mature encoders (`libx264`).
+ Cons: less efficient than newer codecs at high resolutions; not royalty-free (most platforms already pay the license).
+ Use it when the file must play everywhere.

### 3.2 H.265 (HEVC)

High Efficiency Video Coding: up to about half the bitrate of H.264 for similar quality, especially at 4K.
It also supports 10-bit and HDR well.

+ Pros: smaller files at the same quality; good for 4K and HDR.
+ Cons: complex, fragmented licensing; patchy browser support; encoding is much slower than H.264.

### 3.3 VP9

Google's royalty-free codec, with compression roughly comparable to HEVC. Used by YouTube and in WebM files.

+ Pros: free to use; good browser support.
+ Cons: slow software encoding (`libvpx-vp9`); hardware support arrived later than for HEVC, especially on Apple devices.

### 3.4 AV1

Developed by the Alliance for Open Media (AOMedia), whose members include Google, Netflix, Amazon, Microsoft, Mozilla and Apple.
It is designed to be royalty-free and compresses better than VP9 and HEVC.
YouTube and Netflix use it at scale, and current browsers decode it.

+ Pros: best compression of the four; royalty-free.
+ Cons: very slow reference encoder (`libaom-av1`; SVT-AV1 is much faster); hardware decoding and especially encoding exist only on recent chips,
  so older devices decode it in software, using more CPU and battery.

### 3.5 Production codecs

| Codec | From | Notes |
| --- | --- | --- |
| Apple ProRes | Apple | Intra-only, 10/12-bit; recorded by many cameras; standard for editing on macOS |
| DNxHD / DNxHR | Avid | Intra-only; DNxHD for HD, DNxHR for higher resolutions; common in Avid/broadcast workflows |

They produce large files, are easy to edit, and are re-encoded to a delivery codec for distribution.

## 4. Choosing a codec

| Goal | Choice |
| --- | --- |
| Play everywhere (old devices, any browser) | H.264 + AAC in MP4 |
| Smaller files, modern devices | H.265 in MP4 (Apple, TVs) or AV1 in MP4/WebM (browsers, Android) |
| Open web, no royalties | VP9 or AV1 + Opus in WebM |
| Editing / intermediate files | ProRes or DNxHR in MOV |
| Archive several audio/subtitle tracks | MKV with any codec |

On boards, check for hardware support before choosing.
For example, the Raspberry Pi 5 has a hardware HEVC decoder but no hardware video encoder,
and the Jetson Orin Nano has no hardware encoder (NVENC) either, so encoding there runs on the CPU (e.g. `libx264`).
See the vendor documentation for the exact codec list of each board.

ffmpeg encoder names for the codecs above: `libx264`, `libx265`, `libvpx-vp9`, `libaom-av1` / `libsvtav1`, `prores_ks`, `dnxhd`
(`ffmpeg -encoders` lists what your build supports). See [Linux/ffmpeg_cmds.md](Linux/ffmpeg_cmds.md) for commands.

## Related notes

+ [Linux/ffmpeg_cmds.md](Linux/ffmpeg_cmds.md): cutting, converting and encoding videos with ffmpeg
+ [color_spaces_linearity.md](color_spaces_linearity.md): Y'CbCr and chroma subsampling
+ [Linux/yt-dlp_note.md](Linux/yt-dlp_note.md): downloading videos, which often come as VP9 or AV1

## Reference

+ [MDN: Web video codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Video_codecs)
+ [MDN: Media container formats](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Containers)
+ [ITU-T H.264](https://www.itu.int/rec/T-REC-H.264) and [ITU-T H.265](https://www.itu.int/rec/T-REC-H.265)
+ [Alliance for Open Media: AV1](https://aomedia.org/)
+ [FFmpeg codecs documentation](https://ffmpeg.org/ffmpeg-codecs.html)
