# Color spaces and linearity

A color space represents colors as tuples of numbers (usually 3, or 4 with alpha or black ink).
Cameras, screens, printers and human eyes all handle color differently,
so different spaces exist to suit hardware, human perception or data transmission.
This note gives an overview of the common spaces, the three meanings of "linear" in color work,
and what that means for pixel values read with Pillow and OpenCV.

## 1. Overview

| Space | Kind | Device-independent | Linear in light | Typical use |
| --- | --- | --- | --- | --- |
| CIE XYZ | Tristimulus, based on human vision | Yes | Yes | Reference for all other spaces, color profiles |
| Linear RGB | Additive | Only with defined primaries and white point | Yes | Rendering, blending, physics |
| sRGB, Adobe RGB, ProPhoto RGB | Additive, gamma-encoded | Yes (standardized) | No | Images, displays, photography |
| HSV / HSL | Cylindrical form of RGB | No (inherits the RGB space) | No | Color pickers, simple segmentation |
| CIELAB | Perceptual | Yes (relative to a white point) | No | Color difference, print, quality control |
| CIELUV, u'v' | Perceptual / chromaticity | Yes | No (u'v' keeps mixing lines straight) | Lighting, displays |
| Y'CbCr | Luma + chroma, digital | Inherits the RGB space | No | JPEG, MPEG/H.264, video |
| YUV, YIQ, YPbPr | Luma + chroma, analog | Inherits the RGB space | No | PAL, NTSC, component video |
| CMYK | Subtractive | No (depends on inks and paper) | No | Printing |

## 2. CIE XYZ and the (x, y) chromaticity diagram

The CIE (International Commission on Illumination) defined XYZ in 1931 from color-matching measurements
of human observers (the "standard observer"). It was the first mathematically defined color space,
and standard spaces such as sRGB and CIELAB are defined by their conversion to and from XYZ.

+ Y corresponds to luminance; X and Z carry the color information.
+ The values are proportional to light energy, so XYZ is linear (section 9).
+ The **chromaticity** coordinates `x = X/(X+Y+Z)`, `y = Y/(X+Y+Z)` describe color without brightness.
  They are plotted on the familiar horseshoe-shaped CIE 1931 diagram, where gamuts are drawn as triangles.

Use it for color science, color profiles (ICC), and as the bridge when converting between other spaces.

## 3. RGB and the standard RGB spaces

RGB is an **additive** model: colors are mixed from red, green and blue light.
All three at full intensity give white, all at zero give black.
With 8 bits per channel the values run from 0 to 255; 10-, 12-, 16-bit and floating-point formats also exist.

"RGB" by itself is **device-dependent**: the exact red, green and blue primaries differ between monitors, cameras and sensors,
so the same numbers look different on different devices.
A standard RGB space fixes the primaries, the white point and the transfer function (gamma):

| Space | Gamut | Use |
| --- | --- | --- |
| sRGB (IEC 61966-2-1) | Smallest of the three; same primaries as HDTV (BT.709) | Default for the web, consumer monitors, cameras, and most image files |
| Adobe RGB (1998) | Wider than sRGB, mainly in cyan-green | Photography and print work, covers more of the CMYK print gamut |
| ProPhoto RGB | Very wide; covers most real surface colors, and includes some imaginary colors outside human vision | High-end photo editing; needs 16 bits per channel to avoid banding |

Gamut is about which **colors** (chromaticities) can be represented, not about dynamic range (highlights and shadows).

**sRGB transfer function.** sRGB values are not proportional to light.
To convert an encoded value V (scaled to 0..1) to linear light L:

```text
L = V / 12.92                      if V <= 0.04045
L = ((V + 0.055) / 1.055) ^ 2.4    otherwise
```

The overall curve is close to a power of 2.2. For example, sRGB 128/255 is about 21.6% of the light of 255/255, not 50%.

## 4. HSV and HSL

HSV (also HSB) and HSL (also written HLS, e.g. in Python `colorsys` and OpenCV `COLOR_BGR2HLS`) are cylindrical rearrangements of RGB
that match how people describe colors:

+ **Hue (H)**: the color family as an angle on a color wheel, 0° red, 120° green, 240° blue.
+ **Saturation (S)**: from gray to fully saturated.
+ **Value (V)** / **Lightness (L)**: brightness. They differ at the top: V = max with full saturation is a pure color, L = max is always white.

They are simple formulas on the RGB values, so they are device-dependent and **not** perceptually uniform:
yellow and blue at the same V look very different in brightness.
Use them for color pickers, painting tools, and simple hue-based segmentation in OpenCV.
In OpenCV's 8-bit HSV, H is stored as 0..179 (degrees / 2).

## 5. CIELAB (L\*a\*b\*)

CIELAB (1976) is a device-independent space designed to be **approximately perceptually uniform**:
the same numerical distance should look like the same color difference.

+ **L\***: lightness, 0 = black to 100 = the reference white.
+ **a\***: green (−) to red (+).
+ **b\***: blue (−) to yellow (+).

It is defined relative to a reference white (D50 in print/ICC, D65 for sRGB images), so a Lab value needs its white point to be complete.
The color difference ΔE\*ab is the Euclidean distance in Lab. Since Lab is not perfectly uniform,
later formulas such as CIEDE2000 (ΔE00) correct it, especially in blues and saturated colors.

Use it for print production, color matching, quality control, and color-difference measurements.

## 6. CIE 1976 u'v' and CIELUV

### 6.1 u'v' chromaticity

The CIE 1976 **u'v'** Uniform Chromaticity Scale (UCS) diagram is a projective transformation of the CIE 1931 (x, y) diagram:

```text
u' = 4X / (X + 15Y + 3Z)
v' = 9Y / (X + 15Y + 3Z)
```

The problem it solves: the (x, y) diagram is far from perceptually uniform.
The eye notices small (x, y) steps in the blue-violet corner, while large steps in the green region are hard to see.
u'v' stretches and compresses the diagram so that equal distances look roughly like equal color differences (still only approximately).

+ They are pure chromaticity coordinates: color without lightness.
+ The spectral locus stays roughly within 0..0.62 on both axes.
+ Like (x, y), it is a projective transformation of XYZ, so additive mixtures of two lights lie on the straight line between them.

Uses:

+ **Lighting**: LED and lamp specifications, white-point tolerances and color shift are given in Δu'v'.
  Correlated color temperature (CCT) and Duv (distance from the Planckian locus) are defined in the closely related
  CIE 1960 (u, v) diagram, where u = u' and v = (2/3)·v'.
+ **Displays**: plotting display gamuts and calibrating white points, with less distortion than (x, y).

### 6.2 CIELUV (L\*u\*v\*)

CIELUV (1976) was published together with CIELAB. It is built from L\* and from u'v' relative to the white point:

```text
u* = 13 L* (u' - u'n)
v* = 13 L* (v' - v'n)
```

where (u'n, v'n) is the reference white. Lab is mostly used for surface colors (paint, print, textiles),
Luv for emissive light (displays, lighting), because its chromaticity part comes from u'v'.
Once scaled by L\*, straight mixing lines are no longer guaranteed; they hold in the u'v' diagram, not in u\*v\*.

## 7. Video: Y'CbCr, YUV, YPbPr

Video spaces separate brightness from color. The eye resolves brightness detail much better than color detail,
so the color channels can be stored at lower resolution (**chroma subsampling**: 4:2:2, 4:2:0)
with little visible loss, saving a lot of bandwidth.

+ **Y'** (luma): a weighted sum of the **gamma-encoded** R'G'B' values.
  It approximates brightness but isn't true luminance Y, which would be computed from linear RGB.
+ **Cb, Cr**: the scaled blue-difference (B' − Y') and red-difference (R' − Y') signals.
+ The weights depend on the standard: BT.601 (SD video, JPEG) `Y' = 0.299 R' + 0.587 G' + 0.114 B'`,
  BT.709 (HD) and BT.2020 (UHD) use different ones.
+ Video usually uses **limited range**: in 8 bits Y' = 16..235, Cb/Cr = 16..240.
  JPEG uses full range 0..255.

| Name | Domain | Use |
| --- | --- | --- |
| Y'CbCr | Digital | JPEG, MPEG-2, H.264/H.265, camera/ISP output |
| YUV | Analog | PAL (and SECAM) television |
| YIQ | Analog | NTSC television |
| YPbPr | Analog | Component video cables (green = Y, blue = Pb, red = Pr) |

In software, "YUV" is commonly used loosely for digital Y'CbCr: ffmpeg's `yuv420p`, Android `YUV_420_888`, V4L2 `YUYV`, etc. are all Y'CbCr formats.

## 8. CMYK

CMYK (cyan, magenta, yellow, key = black) is a **subtractive** model: inks on paper absorb part of the light
instead of emitting it. In theory C + M + Y make black; in practice they give a muddy dark brown,
so a separate black ink adds deep, sharp blacks and saves colored ink.

CMYK values are device-dependent: the result depends on the inks, paper and press, described by an ICC profile.
Use it for commercial printing, packaging and publishing.

## 9. Three kinds of linearity

"Which color space is linear?" depends on which kind of linearity is meant:

| Linearity | Meaning | Spaces | Use |
| --- | --- | --- | --- |
| Physical light | Doubling a value doubles the light energy | Linear RGB, CIE XYZ | Rendering, lighting, blending, resizing, physics simulation |
| Human perception | Equal steps look like equal differences | CIELAB, CIELUV (approximately); sRGB-encoded values are closer than linear ones | Color difference, quality control, print |
| Color mixing | Mixtures of two lights lie on the straight line between them (Grassmann's laws) | XYZ, linear RGB, and the (x, y) and u'v' chromaticity diagrams | Display calibration, gamut mapping, lighting |

Notes:

+ **Physical light**: sRGB and other standard spaces apply a transfer curve ("gamma") to spend more code values
  on dark tones, where the eye is more sensitive. Values must be linearized before physically meaningful math,
  e.g. averaging two pixels or blurring.
+ **Perception**: linear values are badly non-uniform to the eye: a step near black is very visible, the same step near white is not.
  Lab and Luv were designed to reduce this (and the uneven sensitivity across hues), but are only approximately uniform.
+ **Mixing**: u'v' is uniform-ish **and** keeps mixing lines straight, which is why lighting and display work prefer it over Lab.

## 10. Linearity of pixel values in Python

### 10.1 Pillow and OpenCV return encoded (non-linear) values

Standard 8-bit and 16-bit image files (JPEG, PNG, typical TIFF) store **gamma-encoded** values, usually sRGB.
Neither library linearizes them:

+ **Pillow**: `Image.open()` returns the stored values unchanged (`uint8` 0..255 for RGB images).
  An embedded ICC profile (`img.info.get("icc_profile")`) is ignored unless you convert with `PIL.ImageCms`.
+ **OpenCV**: `cv2.imread()` returns the stored values without color management, in **BGR** channel order.
  By default 16-bit files are reduced to 8 bits; use `cv2.IMREAD_UNCHANGED` (or `cv2.IMREAD_ANYDEPTH`) to keep 16 bits.

Exceptions and pitfalls:

+ **HDR formats**: Radiance `.hdr` and OpenEXR `.exr` files hold linear floating-point data, and OpenCV returns them as `float32`
  with `cv2.IMREAD_UNCHANGED` (or `cv2.IMREAD_ANYDEPTH | cv2.IMREAD_ANYCOLOR`).
  In OpenCV 4.x, EXR support must be enabled with the environment variable `OPENCV_IO_ENABLE_OPENEXR=1` before `cv2` is imported.
+ **16-bit TIFF/PNG** are usually still gamma-encoded, but some tools (raw converters, scientific cameras) write linear data.
  Check how the file was produced.
+ **Grayscale**: `cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)` computes `0.299 R + 0.587 G + 0.114 B` on the encoded values.
  The result is luma, not linear luminance.
+ **Lab in OpenCV**: `COLOR_BGR2Lab` assumes sRGB-encoded input and linearizes it internally.
  For input that is already linear, use `COLOR_LBGR2Lab` / `COLOR_LRGB2Lab`.
  For 8-bit images the output is scaled: L\* × 255/100, a\* + 128, b\* + 128.
  For example, gray 128 gives L = 137 with `COLOR_BGR2Lab` and 194 with `COLOR_LBGR2Lab`.

### 10.2 Converting sRGB to linear and back

```python
import numpy as np
from PIL import Image

def srgb_to_linear(v):
    """v: sRGB values scaled to 0..1 -> linear light 0..1."""
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)

def linear_to_srgb(l):
    """l: linear light 0..1 -> sRGB values 0..1."""
    return np.where(l <= 0.0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - 0.055)

img = np.asarray(Image.open("photo.png").convert("RGB"), dtype=np.float64) / 255.0
lin = srgb_to_linear(img)            # do physical math (blend, blur, resize) here
out = (linear_to_srgb(lin) * 255.0).round().clip(0, 255).astype(np.uint8)
Image.fromarray(out).save("out.png")
```

The same functions work on OpenCV arrays; only the channel order (BGR) differs, which doesn't matter for this per-channel curve.

## Related notes

+ [RGBA_alpha_channel.md](RGBA_alpha_channel.md): RGB with an alpha channel, and image formats that support it
+ [VideoCodecs_note.md](VideoCodecs_note.md): video codecs, which store Y'CbCr with chroma subsampling
+ [Linux/ffmpeg_cmds.md](Linux/ffmpeg_cmds.md): ffmpeg, including pixel formats such as `yuv420p`

## Reference

+ [W3C CSS Color Module Level 4: predefined color spaces and conversion formulas](https://www.w3.org/TR/css-color-4/)
+ [ITU-R BT.601](https://www.itu.int/rec/R-REC-BT.601) and [ITU-R BT.709](https://www.itu.int/rec/R-REC-BT.709)
+ [OpenCV: color conversions](https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html)
+ [OpenCV: imread flags](https://docs.opencv.org/4.x/d8/d6a/group__imgcodecs__flags.html)
+ [Pillow: ImageCms module](https://pillow.readthedocs.io/en/stable/reference/ImageCms.html)
