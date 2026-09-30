# Code-Only Short Film with a Synthesized Score

Make a short film that is rendered live in the browser from code alone: no video files, no pre-rendered images and no editing software.

## Picture
- 4 to 6 scripted scenes, 2D or 3D, with cinematic techniques: cuts between shots, depth of field, colour grading and atmospheric lighting that changes over time.
- All motion of people and scenery comes from algorithms.

## Sound
- An orchestral or ambient score created entirely with the Web Audio API.
- Imitate real instruments (strings, brass, piano, percussion) using additive, FM and physical-modelling synthesis.
- Each instrument only needs to be recognisable as its family, not indistinguishable from a recording.
- Music changes must line up with scene changes.

## Story
A penniless scholar turns down a ghost woman's beauty and her gold. His decency moves her, and she saves him from the demon who holds her captive. After he buries her bones properly she comes back to life, and for the first time, the water reflects her face.

## Technical rules
- One `.html` file that plays on its own from opening to end credits.
- Running time 2–3 minutes.
- No libraries, except Three.js loaded from a CDN if needed. No embedded binary or base64 media.
- A single "click to begin" screen is allowed (browsers block autoplay); no interaction after that.
- Aim for 60 fps at 1080p in Chrome on a recent laptop, and adapt to the window size.
- End credits must credit David Xu.
