Build a native macOS music player app using Swift and SwiftUI in Xcode that closely replicates the UI style, layout, and functionality of Apple Music.

### Key Requirements:

1. **Design & Interface (Apple Music Style):**
   - Translucent macOS design aesthetic featuring a sidebar navigation layout and dark/light system adaptation.
   - **Sidebar Navigation:** Include main library sections for "Songs" (歌曲), "Albums" (专辑), "Artists" (歌手), and custom "Playlists" (播放列表).
   - **Now Playing Bar:** Bottom persistent player bar displaying current track artwork, title, artist, playback controls (Play/Pause, Skip Next/Previous), seekable progress slider, and volume control.
   - **Mini Player:** Support toggling a compact, floating Mini Player window (迷你播放器) overlay.

2. **Audio Playback & Library Management:**
   - Use `AVFoundation` for full audio playback functionality.
   - **File Import:** Provide a local file picker (`NSOpenPanel`) to let users import their own local audio files (MP3/M4A/WAV).
   - **Built-in Test Audio:** Generate or synthesize default sample audio tracks so the player is immediately testable upon launch.
   - **Playlists:** Support creating new custom playlists and adding tracks from the library to playlists.

3. **Views & Detail Screens:**
   - **Songs View:** Clean table/list view showing track titles, artists, album names, and durations.
   - **Albums View:** Grid layout displaying album artwork covers.
   - **Artists View:** Categorized listing by artist.

Provide the complete Xcode project structure and Swift code for immediate compilation and execution.

**Execution note:** Build as a Swift Package (Package.swift + Sources/) that compiles and launches with `swift build`/`swift run` using the installed Command Line Tools (full Xcode is not installed); the package also opens directly in Xcode.
