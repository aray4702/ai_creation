# Hand-Drawn Sketch to Interactive Trebuchet Physics Simulator

Create a single-file web app that converts user-drawn 2D sketches into a functional, real-time 2D physics simulation of a trebuchet.

## Functional Requirements
- **Canvas Sketching Interface**:
  - Draw mode enabling users to sketch structural elements: base frame, main beam, pivot axle, counterweight, sling, and projectile.
  - Automatic geometry recognition parsing lines and circles into 2D rigid bodies and revolute joints (using Matter.js or custom 2D engine).
- **Physics Engine**:
  - Realistic rotational dynamics, torque generation via counterweight drop, sling release mechanism, and projectile trajectory calculation.
- **Analysis & Display**:
  - **Launch Control**: "Trigger / Release" button to execute the launch sequence.
  - **Trajectory Trace**: Render persistent arc displaying projectile path, maximum height, velocity, and landing distance.
  - **Editable Parameters**: Adjustable counterweight mass, sling length, and beam arm ratio.