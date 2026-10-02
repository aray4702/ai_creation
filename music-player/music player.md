# Apple Music–Style Music Player for macOS

A native macOS music player written in Swift and SwiftUI that follows the layout and feel of Apple Music.

## Look and layout
- A translucent macOS design with a sidebar, adapting to light and dark mode.
- **Sidebar:** library sections for Songs, Albums and Artists, plus your own playlists.
- **Now Playing bar:** a bar fixed to the bottom with artwork, title, artist, play/pause, next and previous, a seek bar and a volume control.
- **Mini Player:** a compact floating window you can switch to and back.

## Playback and library
- Audio plays through AVFoundation.
- **Import:** a file picker (NSOpenPanel) for adding your own MP3, M4A or WAV files.
- **Sample tracks:** synthesized demo songs so the app works the moment it opens.
- **Playlists:** create playlists and add songs to them.

## Views
- **Songs:** a clean list with title, artist, album and duration.
- **Albums:** a grid of album covers.
- **Artists:** songs grouped by artist.

**Delivery:** a Swift Package (`Package.swift` + `Sources/`) that builds and runs with `swift build` / `swift run` using only the Command Line Tools, and also opens in Xcode.
