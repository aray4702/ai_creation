# Dead Signal: Atmospheric First-Person Shooter (FPS)

Create an atmospheric first-person shooter where the player must defend a remote radio transmission post from waves of aggressive robotic drones.

## Requirements & Mechanics
- **Asset Creation Constraint**: Construct all 3D weapon models, robot drone models, radio outpost structures, lighting fixtures, and terrain procedurally or in Blender with zero external asset imports.
- **FPS Mechanics & Weaponry**:
  - First-person camera view with weapon sway, recoil impulse, and magazine reload mechanics.
  - Attached flashlight/torch casting real-time dynamic light beams and high-contrast shadows across dark environments.
- **Enemy AI & Defense Objective**:
  - Waves of spider/flying robot drones that spawn, navigate terrain, flank the player, and actively attack the central post and player.
  - Wave progression tracking system displayed as a percentage counter (0% to 100%) until transmission completion.
- **Atmosphere & UI**:
  - Cinematic intro loading animation and dramatic transmission completion sequence with skyward beam visuals.
  - Warning sirens, ambient horror/scifi audio, mechanical footsteps, gunshot audio, and alert HUD overlay.

**Execution note:** Blender is not installed: generate every asset procedurally in code.
