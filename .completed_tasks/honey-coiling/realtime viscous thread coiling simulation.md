# Real-Time Viscous Thread Coiling Simulation (Honey Coiling)

Create a standalone, single-file HTML/WebGL application that simulates the physical phenomenon of viscous liquid thread coiling (such as honey falling from a height onto a flat surface).

## Physics & Technical Specifications
- **Viscous Fluid Mechanics**: Implement real-time numerical approximation of liquid viscous thread coiling, capturing bending, twisting, and inertia dynamics of a thin fluid stream.
- **Rendering**: Use Three.js / WebGL with custom shaders to render realistic honey/amber material translucency, subsurface scattering, dynamic reflections, and fluid thickness variation.
- **Interactive GUI**:
  - **Pour Height**: Adjustable nozzle elevation relative to the surface.
  - **Kinematic Flow Rate**: Control liquid injection speed and volume flow rate.
  - **Viscosity & Surface Tension**: Sliders to tweak dynamic viscosity, surface tension, and liquid density.
  - **Coiling Modes**: UI indicator displaying the active physical coiling regime (Viscous, Gravitational, Inertial, or Inertio-Gravity).
  - **Camera Controls**: OrbitControls with pan, zoom, reset, and preset cinematic camera angles.
- **Performance Requirement**: All physics calculations must run at 60 FPS in real-time within a single self-contained `.html` file.