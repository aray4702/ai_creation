# Real-Time Multiplayer Lawn Mowing Simulator

Build a real-time multiplayer web game where players operate lawn mowers together on a shared persistent lawn.

## Mechanics & Multiplayer Setup
- **Lawn Mowing Physics**:
  - Procedural grass grid blade tracking where mowers cut tall grass down to manicured lawn strips in real time.
  - Mower vehicle handling with engine sound synthesis and grass particle discharge.
- **Multiplayer System**: WebSocket/WebRTC implementation enabling multiple concurrent players to connect, steer mowers, and view each other's progress.
- **Character Touches**: Playable driver options, item usage (e.g., cold drinks, cigars), and dynamic scoreboards tracking percentage of lawn mowed per player.

**Execution note:** Deliver a Node.js server (`server.js`, no npm dependencies) that serves the client and relays WebSocket state, plus the browser client. Multiplayer is verified locally with several browser windows via `node server.js`.
