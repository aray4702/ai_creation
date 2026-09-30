# Painterly Music Video Engine

Given a song and its lyrics, produce a complete animated music video, about two and a half minutes long, that runs as a single WebGL/Canvas web page.

## Structure
- Organise the video as separate scene modules, as if different agents each own a part. Each module is driven by a timeline of keyframes tied to the song's beats and to when each lyric line is sung.

## Painted look
- Canvas/shader effects that draw everything with visible, moving brush strokes, so each scene feels hand-painted.
- Characters, backgrounds and camera moves are animated in an impressionist painted style.

## Following the music
- Use the Web Audio API to analyse the track and let its beats and frequency spectrum drive scene changes, how fast strokes flow, and changes in lighting.
- Built-in play/pause controls and a live spectrum or waveform display.

## Delivery
- One runnable HTML/JavaScript file containing every shader, art generator and piece of audio-sync code.
