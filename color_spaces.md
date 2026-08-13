# color spaces

Color spaces are mathematical models used to represent colors as tuples of numbers (usually 3 or 4 values).  
Because different devices (like cameras, screens, and printers) and human eyes process color differently,  
various color spaces exist to optimize for hardware, human perception, or data transmission.

## CIE XYZ (CIE 1931 Color Space)

+ Type: Device-independent master color space.
+ How it works: Created by the International Commission on Illumination (CIE) in 1931,  
  this was the first mathematically defined color space based on direct measurements of human eye sensitivity (the standard observer).  
  All other color spaces—including Lab and sRGB—are mathematically mapped back to XYZ.
+ Best for: Color science research, defining color profiles, and serving as the mathematical bridge between different color spaces.

## RGB (Red, Green, Blue)

+ Type: Additive color model.
+ How it works: Colors are created by mixing different intensities of Red, Green, and Blue light.  
  In digital systems, each channel typically ranges from 0 to 255.  
  Combining all three at maximum intensity produces white; combining them at zero produces black.
+ Best for: Electronic displays, computer monitors, television screens, and digital cameras.
+ Limitation: It is device-dependent—pure red on one monitor might look slightly different on another because hardware implementations vary.

## Standardized RGB Variants (sRGB, Adobe RGB, ProPhoto RGB)

Because raw RGB is device-dependent, industries created standardized "flavors" of RGB to ensure consistency across screens and software:

+ sRGB: The global standard for the web, standard monitors, and consumer cameras.  
  It has a smaller color gamut (range of reproducible colors) ensuring that images look consistent across almost any screen.
+ Adobe RGB: Designed for professional graphic design and print workflows. It encompasses a wider range of cyan and green shades than sRGB.
+ ProPhoto RGB: A massive color space used primarily in high-end digital photography.  
  It covers over 90% of colors perceivable by the human eye, capturing extreme highlights and shadows for archival purposes.

## HSV / HSL (Often referenced as LHS)

+ Type: Cylindrical-coordinate representations of the RGB color space designed to align with how humans conceptualize color.
+ Components:  
  + Hue (H): The color family or pigment type, measured as an angle from 0° to 360° on a color wheel (e.g., 0° is red, 120° is green, 240° is blue).
  + Saturation (S): The purity or intensity of the color (from gray to fully saturated).
  + Value (V) / Lightness (L): The brightness of the color.
+ Best for: Digital painting software, color pickers, and graphic design tools where humans need to intuitively tweak tints and shades.

## CIELAB (Lab)

+ Type: **device-independent**, perceptually uniform color space.
+ How it works: Designed to approximate human vision, where a numerical change in value corresponds to a matching visual change in perception.
+ Components:
  + L: Lightness (from 0 for absolute black to 100 for absolute white).
  + a*: The green (-) to red (+) axis.
  + b*: The blue (-) to yellow (+) axis.
+ Best for: Print production, color matching, and scientific color analysis where accurate, uniform perception across different media is crucial.

## CIE 1976 Chromaticity Coordinates: u'v'

The term u'v' (pronounced "u-prime v-prime") refers to the CIE 1976 u'v' Uniform Chromaticity Scale (UCS) diagram.  
It is the foundation of the CIELUV color space and was designed to fix a major flaw in older color maps
The u'v' diagram stretches and compresses the 1931 space mathematically  
so that equal distances on the graph roughly correspond to equal perceived color differences to the human eye.

+ What they are: These are pure chromaticity coordinates (color-only, *independent of lightness*).  
  They are used to plot colors on a 2D uniform chromaticity scale diagram.
+ Range: Typically bounded between 0 and 0.62.
+ Formula connection: They are the raw intermediate values calculated from XYZ before factoring in lightness (L*).

### The Problem It Solves

Perceptual UniformityThe classic CIE 1931 (x,y) chromaticity diagram is great for mapping light, but it is not perceptually uniform.  

+ On an (x,y) plot, the human eye is extremely sensitive to changes in certain areas (like blue) and much less sensitive in others (like green).  
+ Equal geometric distances on an (x,y) map do not equal equal visual color differences.  

### Primary Uses

+ Lighting Design & Correlated Color Temperature (CCT): The u'v' diagram is heavily used to evaluate white light sources (like LEDs and bulbs)  
  and plot Planckian (blackbody) radiation curves.
+ Computer Graphics & Additive Displays: Because additive mixtures of light fall on a straight line in the u'v' uniform chromaticity space,  
  it is widely used in rendering, projection, and display calibration where light mixing is key.

## CIELUV Color Space Coordinates

+ What they are: These are the scaled, psycho-perceptual Cartesian coordinates that make up the `L*u*v*` (CIELUV) color space.
+ Type: Another **device-independent**, perceptually uniform color space created around the same time as Lab.
+ How it works: While Lab is great for surface colors (like paint and print), Luv was designed with a focus on uniform chromaticity scales for additive color mixtures.
+ Best for: Computer graphics, lighting design, and applications involving projected light where color mixture linearity matters.
+ How they relate: They take u' and v', **subtract the reference white point** (u_n', v_n'),  
  and scale the result by lightness (L*) so that color differences are more perceptually uniform.

## YCbCr

+ Type: Color space used primarily in video engineering and digital compression.
+ How it works: It separates image data into brightness and color information:
  + Y: Luma (brightness/luminance component).
  + Cb & Cr: Chroma components representing the blue-difference and red-difference from reference white.
+ Best for: Video broadcasting, JPEG compression, and MPEG formats.  
  Because the human eye is far more sensitive to brightness changes than to color details,  
  YCbCr allows systems to discard some color data (chroma subsampling) to save massive amounts of bandwidth without a noticeable loss in perceived image quality.

## YUV / YPbPr

+ Type: Analog video color spaces.
+ How it works: These are the analog predecessors to digital YCbCr.
+ YUV: Used historically in analog television broadcasting (like PAL and NTSC).
+ YPbPr: Used in analog component video cables (the red, green, and blue-coded RCA cables for older DVD players and consoles).
+ Best for: Legacy analog video transmission, encoding color efficiently while separating brightness from color channels.

## CMYK (Cyan, Magenta, Yellow, Key/Black)

+ Type: Subtractive color model.
+ How it works: Unlike monitors that emit light (additive), physical print absorbs light.  
  CMYK uses inks that subtract certain wavelengths from white light.  
  Combining all three primary inks theoretically makes black, but in practice, it creates a muddy dark brown.  
  Therefore, a fourth channel (Key or Black) is added to provide deep, sharp blacks and save on colored ink.  
+ Best for: Commercial printing, packaging, and publishing (magazines, books, flyers).

## linearity

When asking which color space is more linear, the answer depends entirely on what kind of linearity you are looking for.  
In color science, linearity is divided into 3 distinct categories: physical light (intensity), human perception, and color mixing.

### 1. Linearity to Physical Light (Intensity Linearity)

If you want a space where doubling the numerical value literally means doubling the amount of light energy (photons) emitted or captured, you are looking at:

+ Linear RGB & CIE XYZ
+ Why: Standard consumer color spaces like sRGB are non-linear because they apply a gamma correction curve to match how human eyes process shadows versus highlights. However, "Linear RGB" (raw RGB without gamma) and CIE XYZ are strictly mathematically proportional to physical light energy.
+ Best for: 3D rendering, computer graphics lighting engines, and physics simulations.

### 2. Linearity to Human Vision (Perceptual Linearity)

If you want a space where an equal numerical step anywhere in the color space represents an equal visual change to the human eye,  
you are looking at:

+ CIELAB and CIELUV
+ Why: Standard RGB and XYZ are terribly non-linear for human perception—a tiny change in numerical values can cause a massive visual shift in dark blues, while the exact same numerical change in greens might be invisible. Lab and Luv were specifically engineered to stretch and squash the math so that distance equals perceived difference.
+ Best for: Color difference evaluation, quality control, and printing.

### 3. Linearity for Color Mixing (Chromaticity Linearity)

If you want a space where mixing two different colors results in a straight line connecting them on a graph (following Grassmann's laws of additive color mixture):

+ CIE XYZ (mathematically linear for mixing)
+ CIELUV / u'v' (optimized so that chromaticity mixtures are visually/perceptually uniform along straight lines).
+ Best for: Display calibration, lighting design, and color gamut mapping.

## python modules

### Pillow, Image.open() output is not linear

Why they are not linear:

+ Non-Linear Storage: Standard image formats like TIFF (lena_std.tif), JPEG, and PNG **store pixel values in a non-linear color space** (typically sRGB).  
  These values are **gamma-encoded** (roughly following a power curve of gamma approx 2.2) to match human perceptual sensitivity and legacy CRT monitor characteristics.  
+ Pillow's Behavior: When you use `Image.open('lena_std.tif')`, Pillow simply reads the raw pixel data stored in the file  
  (usually 8-bit integers from 0 to 255 per channel) without applying any radiometric or linearization transforms.

#### How to convert them to linear intensity (if needed)

If your workflow requires physically linear light intensities  
(e.g., for computer graphics, optical simulations, or accurate blending),  
you must explicitly remove the sRGB gamma correction.

### OpenCV: cv2.imread()

images read using cv2.imread() are NOT intensity-linear.  
(for standard 8-bit or 16-bit integer formats like JPEG, PNG, or standard TIFF).

#### Why they are not linear

+ Raw File Data: By default, `cv2.imread()` reads the **encoded pixel values** directly from the file container  
  without applying any color space transformations or gamma correction removal.
+ sRGB Space: Standard consumer images are saved in the sRGB color space,  
  meaning their values are **gamma-encoded** to match human perception and display standards.  
  Therefore, an OpenCV image array contains non-linear values.

#### Important Exceptions

+ HDR and EXR Formats: If you are reading high dynamic range formats (such as .hdr or .exr) using flags like `cv2.IMREAD_ANYDEPTH` or `cv2.IMREAD_LOAD_GDAL`,  
  OpenCV will load them as floating-point values that are physically linear.
+ Grayscale Conversions: If you convert the image using `cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)`,  
  the resulting intensity values are still derived from the non-linear sRGB channels,  
  not true linear luminance (unless you linearize the sRGB values first).
