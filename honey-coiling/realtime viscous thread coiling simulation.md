# Honey Coiling: Real-Time Viscous Thread Simulation

A single self-contained HTML/WebGL page that reproduces what happens when a thin stream of something thick, like honey, is poured from a height onto a flat surface: it piles up in coils.

## Physics
- A real-time numerical model of the falling thread that accounts for how it bends, twists and carries momentum, so the coiling emerges from the simulation.
- Everything must keep running at 60 fps.

## Look
- Three.js/WebGL with custom shaders for an amber, honey-like material: see-through, with light scattering inside it, live reflections, and a thread that thins and thickens.

## Controls
- **Pour height:** how high the nozzle sits above the surface.
- **Flow rate:** how fast and how much liquid comes out.
- **Fluid properties:** separate sliders for viscosity, surface tension and density.
- **Regime readout:** a label showing which coiling regime is active: viscous, gravitational, inertial, or inertio-gravitational.
- **Camera:** orbit, pan, zoom, a reset button and a few preset cinematic angles.
