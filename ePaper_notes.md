# color electronic paper

Kaleido, Gallery, and ChLCD are distinct reflective display technologies used for color electronic paper.  

+ Kaleido uses a black-and-white panel with an RGB color filter,
+ Gallery uses particle mixing for full color,
+ ChLCD uses stacked cholesteric liquid crystal layers.

## E Ink Kaleido (e.g., Kaleido 3)

+ How it works: Adds a microscopic color filter array on top of a standard monochrome E Ink panel.
+ Pros: Fast refresh rates close to black-and-white e-paper; great for reading comics, UI navigation, and taking notes.
+ Cons: Muted, pastel colors; lower resolution for color content (approx. half the monochrome PPI).

## E Ink Gallery (e.g., Gallery 3)

+ How it works: Uses ACeP (Advanced Color ePaper) technology with colored pigment particles moving inside microcapsules  
  to mix full color at the pixel level without a filter.
+ Pros: Rich, full-color saturation and higher color PPI.
+ Cons: Noticeably slower refresh and page-turn speeds compared to Kaleido.

## Cholesteric Liquid Crystal (ChLCD)

+ How it works: Uses three stacked layers of helical liquid crystals reflecting red, green, and blue light  
  without filters or backlights, achieving millions of native colors.
+ Pros: High color saturation, vivid gradients, fast video-capable refresh rates relative to particle-based full color, and low power usage.
+ Cons: Colors can shift slightly depending on the viewing angle compared to particle E Ink; less common in mainstream consumer e-readers.

## ePaper palette

Converting an image to match the specific CIELAB (Lab) color palette of an ePaper display ensures that  
colors are mapped based on human perceptual uniformity rather than raw RGB values.  
Because ePaper displays (like 3-color, 4-color, or 7-color ACeP panels) rely on physical pigments,  
matching them in Lab space provides the most accurate color translation.

The complete workflow and a Python implementation using scikit-image, NumPy, and SciPy accomplish this conversion.

### Step-by-Step Workflow

1. Load and Normalize: Read the source image and normalize pixel values to the range [0.0, 1.0].
2. Convert to CIELAB: Convert the source image from sRGB to the CIE La*b* color space.
3. Define the ePaper Palette: Specify the target ePaper colors expressed as La*b* coordinates.
4. Nearest-Neighbor Matching: Flatten the image pixels and use a spatial search tree (**KDTree**)  
   to find the closest matching ePaper palette color for every single pixel based on Euclidean distance in Lab space (Delta E).
5. Reconstruct and Convert Back: Reshape the pixel array back into the image dimensions and convert the result back to sRGB for saving or rendering.

### Pro-Tips for ePaper Color Matching

+ Manufacturer Specifications: Check your ePaper display's datasheet.  
  Many commercial display vendors (like Waveshare or Good Display) provide precise RGB or Lab values for their specific pigment particles.
+ Dithering: Because ePaper palettes are extremely restricted, sharp color transitions can look posterized.  
  If you want smoother gradients, consider implementing an Error-Diffusion Dithering algorithm  
  (such as Floyd-Steinberg) directly in the Lab color space prior to final quantization.
