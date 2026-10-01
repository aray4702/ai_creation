# Viscous Fluid Coiling & Buckling on a Moving Conveyor Belt

Develop a single-file HTML5 WebGL physics application simulating thin viscous streams (syrup/liquid) falling onto a moving horizontal conveyor belt.

## Simulation Requirements
- **Fluid & Belt Dynamics**:
  - Simulate thin liquid streams discharging vertically onto a moving belt surface.
  - Model fluid buckling, meandering, coiling, and straight-line deposition regimes based on belt velocity, fluid fall height, and flow rate.
- **Visuals & Shader Details**:
  - Glossy, semi-transparent liquid shader with specular highlights and specular reflections representing golden syrup.
  - Moving conveyor belt texture with adjustable speed indicator.
- **Control Panel**:
  - **Belt Speed**: Slider ranging from static (0 m/s) to high speed.
  - **Drop Height**: Vertical distance from nozzle to belt.
  - **Nozzle Radius & Flow Velocity**: Dynamic thread thickness adjustments.
  - **Real-Time Graph**: Live plot showing the transition boundaries between coiling, figure-eight, zigzag, and straight deposition patterns.