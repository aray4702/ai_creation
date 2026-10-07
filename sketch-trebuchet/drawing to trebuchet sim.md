# Hand-Drawn Sketch to Trebuchet Physics Simulator

A single-file web app that turns a user's 2D sketch into a working, real-time 2D physics simulation of a trebuchet.

## Sketching
- A drawing canvas where users sketch the structural parts: base frame, main beam, pivot axle, counterweight, sling and projectile.
- Automatic geometry recognition that turns the drawn lines and circles into 2D rigid bodies and revolute joints (using Matter.js or a custom 2D engine).

## Physics
- Realistic rotational dynamics: torque from the falling counterweight, the sling release mechanism, and the projectile's trajectory.

## Analysis and display
- **Launch control:** a "Trigger / Release" button that runs the launch sequence.
- **Trajectory trace:** a persistent arc showing the projectile's path, maximum height, velocity and landing distance.
- **Editable parameters:** counterweight mass, sling length and beam arm ratio.
