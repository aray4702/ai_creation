# Interactive Camera Lens Lab & Optical Focus Simulator

Create a standalone, single-file WebGL/Canvas application that interactively demonstrates optical physics and camera lens mechanics.

## Technical & Physical Requirements
- **Optical System Modeling**:
  - Model a multi-element camera lens cross-section (e.g., focus group, zoom group, aperture diaphragm).
  - Calculate optical ray paths through glass elements using Snell's law of refraction.
- **Interactive Controls**:
  - **Focus Ring**: Tactile ring control that physically moves internal lens elements along the optical axis.
  - **Aperture Control**: Dynamic mechanical aperture blades opening/closing to alter depth of field and light throughput.
  - **Focal Plane Plane**: Render a visible plane passing through the 3D scene indicating the exact plane of sharp focus.
- **Visuals**:
  - Real-time bokeh rendering and background depth-of-field blur corresponding to the current aperture setting.
  - Split view showing the structural optical ray tracing on top and the resulting camera view on the bottom.
- **Constraints**: Single self-contained `.html` file with zero external framework dependencies, executable directly in any web browser.