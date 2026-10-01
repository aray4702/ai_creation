# Interactive Camera Lens Optics & Ray Tracing Explainer

Build an interactive single-file HTML/WebGL educational visualization showing optical physics and ray tracing inside multi-element camera lenses.

## Features & Optical Physics
- **Multi-Element Lens System**:
  - Model convex, concave, and aspheric lens elements inside a cross-sectioned camera barrel.
  - Real-time ray tracing calculating Snell's Law refraction across each glass surface.
- **Interactive Controls**:
  - **Aperture Blade Adjustment**: Dynamic mechanical iris control (e.g., f/1.4 to f/22) altering ray entry angles and light throughput.
  - **Focus Ring & Zoom**: Shift lens groups horizontally to illustrate focal length variation (e.g., 24mm wide-angle vs 85mm prime) and focus shift.
  - **Chromatic Aberration & Dispersion**: Toggle wave-length dependent refraction (dispersion of red, green, blue light rays).
- **Visual Output**: Dual view showing the 2D optical ray diagram on top and a rendered 3D camera preview image below demonstrating depth of field and bokeh blur.