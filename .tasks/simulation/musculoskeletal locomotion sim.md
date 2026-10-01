# Physics-Based Musculoskeletal Locomotion & Balance Simulation

Build an interactive, real-time 3D musculoskeletal physics engine inside a single HTML file using Three.js and Cannon.js/Ammo.js.

## Physics & Control Mechanics
- **Anatomy**:
  - Rigged character structure built from rigid bones connected by revolute/spherical joints.
  - Elastic muscle-tendon actuators (Hill-type muscle model) attached to skeleton anchor points.
- **Locomotion & Controller**:
  - Neural network or feedback-driven controller adjusting muscle contractions to achieve balance and forward walking strides.
  - Model real-world muscle delay (latency between activation and force generation) and elastic springiness.
- **Interactivity**:
  - **Perturbation Impulse**: Click and drag on any body part or apply an external push/blast force to disturb balance.
  - **Tall/Unstable Preset**: Option to spawn a tall, high-center-of-gravity "wobbly" character model.
  - **Data Visualization**: Toggle overlay showing muscle force vectors, active tension levels (color-coded red to blue), and center-of-mass trajectory.