Analyze the attached 2D indoor architectural floor plan image and generate a full 3D interactive, explorable house model using Three.js and WebGL.

### Functional Requirements:
1. **Floor Plan Translation:**
   - Accurately parse wall boundaries, room partitions, door locations, and multi-floor stairs from the provided image.
   - Build a 2-story architectural structure with separate togglable top-down floor views (First Floor / Second Floor).
2. **Interactive First-Person Exploration:**
   - Enable WASD / Arrow Key locomotion and mouse look controls to walk through the interior.
   - Implement collision detection against walls, furniture, and stairs.
   - Add proximity-based automatic door opening and closing as the player walks through doorways.
3. **Interior Furnishing & Realism:**
   - **Living Room:** Sofa set, coffee table, media unit, TV with ambient backlighting, realistic wood-grain floor texturing, and potted plants.
   - **Kitchen & Dining:** Dining table with chairs, kitchen cabinets, stove counter, range hood, sink, and refrigerator.
   - **Bedrooms & Balcony:** Fully furnished master bedroom leading out to an outdoor balcony with patio furniture and outdoor plants.
   - **Bathroom:** Frameless glass shower enclosure, vanity mirror with reflection, and tile floor textures.
   - **Lighting:** Dynamic interior ceiling lights, window daylighting with exterior foliage views, and soft shadows.