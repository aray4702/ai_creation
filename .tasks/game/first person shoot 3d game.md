Create a 3D First-Person Shooter (FPS) browser game using Three.js with complete gameplay mechanics and combat physics.

### Core Features:
1. **Player Controls & Movement:**
   - First-person perspective camera with Pointer Lock controls for aiming.
   - WASD movement, jumping, and crouch/cover mechanics inside a multi-story building environment.
2. **Weapon Systems & Combat:**
   - Multiple selectable weapons (Pistol vs. Assault Rifle) with distinct fire rates, muzzle flashes, and magazine reload animations.
   - **Throwable Explosives:** Press key to throw grenades with parabolic trajectory physics, explosion particle effects, and splash damage.
3. **Enemy AI & Tactical Combat:**
   - Enemy combatants positioned across the map with line-of-sight detection and counter-firing capabilities.
   - Multi-level vertical combat (firing from upper balconies or seeking cover behind obstacles).
4. **Game UI & Performance:**
   - HUD displaying crosshair, health bar, ammo count, weapon indicator, and hit markers.
   - Clean death screen / game over state with restart capability.
   - Optimize render loop to maintain smooth 60 FPS performance without CPU thermal throttling.