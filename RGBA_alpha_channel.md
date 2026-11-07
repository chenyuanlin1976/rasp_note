# RGBA and the alpha channel

RGBA is a **pixel format**, not a file format: each pixel stores red, green and blue plus an **alpha** (A) value
that says how opaque the pixel is. Image file formats such as PNG or WebP can store RGBA pixels; others, such as JPEG, can't.
Examples were checked with Pillow 9.0.1 and OpenCV 4.12.0.

## 1. RGB vs. RGBA

| | RGB | RGBA |
| --- | --- | --- |
| Channels | R, G, B | R, G, B, A |
| Transparency | None: every pixel is opaque | Per pixel, from fully transparent to fully opaque |
| 8-bit pixel size | 3 bytes | 4 bytes |
| Typical use | Photos, video frames | Icons, logos, UI elements, overlays, sprites, layers |

## 2. Alpha values

The alpha range follows the channel depth, like the color channels:

| Storage | Transparent | Opaque |
| --- | --- | --- |
| 8-bit integer | 0 | 255 |
| 16-bit integer | 0 | 65535 |
| Floating point (shaders, compositing math) | 0.0 | 1.0 |

Example: `(255, 0, 0, 128)` is red at about 50% opacity.

Channel order varies between libraries and hardware: RGBA (PNG, Pillow, OpenGL), BGRA (Windows, OpenCV),
ARGB (some graphics APIs and framebuffers). Check the order before reinterpreting raw bytes.

## 3. Compositing ("over")

Placing a foreground pixel F with alpha a (0..1) over a background pixel B gives:

```text
result = a * F + (1 - a) * B
```

For example, `(255, 0, 0, 128)` over opaque blue `(0, 0, 255)` gives about `(128, 0, 127)`.

+ **Straight (unassociated) alpha**: R, G, B hold the full color and alpha is separate. PNG uses this.
+ **Premultiplied (associated) alpha**: R, G, B are already multiplied by alpha, so "over" becomes `F + (1 - a) * B`.
  Common inside GPUs and compositors because it filters and blends correctly. Mixing up the two gives dark or bright fringes at edges.
+ Correct blending is done on **linear** light. Most libraries blend the sRGB-encoded values directly,
  which is faster but slightly darkens semi-transparent edges (see [color_spaces_linearity.md](color_spaces_linearity.md)).

## 4. File format support

| Format | Alpha | Notes |
| --- | --- | --- |
| PNG | Yes, 8 or 16 bits | Lossless; the most common format for RGBA images |
| WebP | Yes | Lossy or lossless, with alpha |
| AVIF, HEIF, JPEG XL | Yes | Modern formats, with alpha |
| TIFF | Yes | Extra sample marked as alpha; reader support varies |
| GIF | 1 bit only | One palette index can be marked fully transparent; no partial transparency |
| BMP | Partly | 32-bit BMPs can carry alpha, but many readers ignore it |
| JPEG | No | Lossy, color only. Pillow refuses to save RGBA as JPEG: convert to RGB first |

## 5. Python: keeping or dropping alpha

```python
from PIL import Image
import cv2

im = Image.open("logo.png")              # mode "RGBA" if the PNG has alpha
rgba = im.convert("RGBA")                # add an opaque alpha channel if missing
alpha = rgba.getchannel("A")             # alpha as a grayscale image

bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
flat = Image.alpha_composite(bg, rgba).convert("RGB")   # flatten onto white
flat.save("logo.jpg")                    # JPEG needs RGB

img = cv2.imread("logo.png")                          # 3 channels: alpha dropped
img = cv2.imread("logo.png", cv2.IMREAD_UNCHANGED)    # 4 channels, BGRA order
```

`convert("RGB")` on its own simply discards alpha, so transparent pixels show whatever color they happen to store (often black).
Composite onto a background first, as above.

## Related notes

+ [color_spaces_linearity.md](color_spaces_linearity.md): RGB and other color spaces, and why blending should be done on linear light

## Reference

+ [PNG Specification (W3C)](https://www.w3.org/TR/png/)
+ [Pillow: Image module](https://pillow.readthedocs.io/en/stable/reference/Image.html)
+ [OpenCV: imread flags](https://docs.opencv.org/4.x/d8/d6a/group__imgcodecs__flags.html)
