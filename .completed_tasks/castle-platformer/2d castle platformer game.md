# Rampart: 2D Castle Platformer Game

Build a complete, standalone 2D castle platformer video game with procedural graphics, audio, and polished UI.

## Requirements & Mechanics
- **Asset Creation Constraint**: Generate all game assets, character models, tilesets, and animations procedurally or via procedural Blender script generation. Do NOT download any external assets or libraries from the internet.
- **Player Mechanics**:
  - Smooth left/right movement with momentum.
  - Jump and double-jump mechanics.
  - Stomp mechanic: Jump onto enemy heads to defeat them.
  - Health/respawn system for falling off platforms or touching hazards.
- **Level & World Design**:
  - Castle-themed platforming level layout with elevation shifts, floating platforms, and enemy patrol units.
  - Goal flag pole at the end of the level triggering a victory sequence upon collision.
- **Visuals & UI**:
  - Clean title screen with a custom game logo and emblem (e.g., cross swords).
  - Polished HUD showing health, score, and level progression in the top-left corner.
  - Polished victory overlay screen with performance stats upon level completion.
- **Audio**: Procedural background chiptune/castle music and custom jumping/stomp sound effects using Web Audio API or generated audio clips.

**Execution note:** Blender is not installed: generate every asset procedurally in code.
