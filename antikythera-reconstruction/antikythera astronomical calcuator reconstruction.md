# Antikythera Mechanism: Interactive 3D Reconstruction

Make a browser-based 3D model of the Antikythera Mechanism, the ancient Greek geared device often called the first astronomical computer. Use Three.js/WebGL, and base the design on what the surviving fragments show.

## What it needs to do

**Take it apart visually**
- Model the full internal gearing: the gear trains, the differential assembly and the hand-turned drive crank.
- Add an "explode" control that pulls the parts away from each other so the user can see how the layers of gears fit together.

**Teach through the parts**
- Every gear can be clicked. Clicking one opens an info card with its tooth count, what it drives, and the role it plays in the calculation.

**Compute the sky**
- Turning the crank advances the mechanism and updates its astronomical outputs:
  - where the Sun is
  - the Moon's phase cycle
  - predicted eclipses
- Give the user controls to drive the crank and read these results.
