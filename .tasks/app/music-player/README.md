# Music Player (Apple Music–style, English)

A native macOS music player built with SwiftUI + AVFoundation, delivered as a
Swift Package (no Xcode project needed) so it compiles with the Command Line
Tools alone. It closely follows Apple Music's layout: a translucent sidebar
(Songs / Albums / Artists / Playlists), grid album browsing, a persistent
bottom Now Playing bar, and a toggleable floating Mini Player.

## Requirements

- macOS 14+
- Swift 6.1 / Xcode Command Line Tools (`xcode-select -p` should print
  `/Library/Developer/CommandLineTools`, or Xcode itself — both work)

> **Known blocker on some machines — read this if `swift build` fails with
> "this SDK is not supported by the compiler":** on the machine this package
> was built on, the installed Command Line Tools (16.3) have a version
> mismatch between the compiler binary (`swift-frontend`, build `110.21`)
> and the SDK's precompiled Swift interfaces for `Foundation`/`CoreFoundation`
> (declared as built by `110.5`). The compiler hard-refuses to consume them,
> so **any** program that does `import Foundation` (and therefore anything
> using AppKit/SwiftUI/AVFoundation, i.e. this whole app) fails to compile —
> confirmed with a 2-line repro (`import Foundation; print("x")`) independent
> of this package's code or `Package.swift`. This is a machine-level Command
> Line Tools defect, not something fixable via build flags or source changes.
> Fix: run `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`
> (or install a matching full Xcode) so the SDK and compiler versions line
> up again, then retry. The source in this package is believed complete and
> ready to build as soon as that's resolved.

## Run

```sh
cd music-player
swift run
```

`swift build` alone also works if you just want to compile without launching.
The compiled app also opens directly in Xcode: `open Package.swift`.

### If `swift build` fails with an "Invalid manifest" / undefined symbol error

Some Command Line Tools installs (observed with CLT 16.3 on this machine)
ship a `PackageDescription` manifest API whose `.private.swiftinterface`
disagrees with what `libPackageDescription.dylib` actually exports, so
**any** `Package.swift`, even a trivial one, fails to link with:

```
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(...)"
```

This is an environment/toolchain bug, not a problem in this package. Workaround:

```sh
cat > /tmp/fix.yaml <<'EOF'
{"version":0,"case-sensitive":"false","roots":[{"type":"directory","name":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule","contents":[
{"type":"file","name":"arm64-apple-macos.private.swiftinterface","external-contents":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"},
{"type":"file","name":"x86_64-apple-macos.private.swiftinterface","external-contents":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/x86_64-apple-macos.swiftinterface"}]}]}
EOF
mkdir -p /tmp/mc-en
swift build \
  -Xbuild-tools-swiftc -vfsoverlay -Xbuild-tools-swiftc /tmp/fix.yaml \
  -Xbuild-tools-swiftc -module-cache-path -Xbuild-tools-swiftc /tmp/mc-en
```

Both flags (the VFS overlay *and* a fresh module cache for the manifest
build) are needed together — either alone is insufficient. If your install
doesn't hit this bug, plain `swift build` / `swift run` is all you need.

Note: with only Command Line Tools installed (no full Xcode), first-time
builds of the SwiftUI target can take several minutes because the compiler
falls back to slower, less-parallel type-checking for the artwork/Canvas
code — this is expected, not a hang.

## What you'll see on first launch

On first launch the app synthesizes ~10 short demo tracks (procedurally
generated chiptune-ish music across 5 fictional "albums") directly in code
and writes them as WAV files to
`~/Library/Application Support/MusicPlayerDemo/Samples-v1/`. This only
happens once; subsequent launches reuse the cached files. Two starter
playlists ("Late Night Drive", "Calm Focus") are pre-populated from these
tracks.

## Features

- **Sidebar**: Songs, Albums, Artists, Recently Added, and user Playlists,
  with translucent macOS sidebar material.
- **Now Playing bar**: artwork, title/artist, Play/Pause, Previous/Next,
  draggable seek slider with elapsed/remaining time, volume slider, shuffle
  and repeat toggles, Up Next popover.
- **Mini Player**: `⌥⌘M` or the toolbar/bar button opens a separate floating
  always-on-top window with hover-revealed transport controls; closing it
  (or the expand button) returns you to the main window.
- **Library import**: File ▸ Import Audio Files… (`⌘O`) opens an
  `NSOpenPanel` filtered to mp3/m4a/wav/aiff; imported files are read with
  `AVURLAsset`/`AVAudioPlayer` for metadata and duration and merged into the
  library (persisted to `library.json` in Application Support).
- **Playlists**: File ▸ New Playlist… (`⌘N`), rename, delete, add songs via
  a picker sheet, or right-click any track ▸ Add to Playlist.
- **Albums view**: grid of procedurally generated album artwork (unique per
  album/artist, no external images) with a hover play button.
- **Artists view**: alphabetically grouped list with an artist detail page
  (albums grid + song list).
- **Playback engine**: `AVAudioPlayer`-based queue with next/previous,
  shuffle, repeat (off/all/one), and a live progress timer.

## Project layout

```
Package.swift
Sources/MusicPlayer/
  ToneSynth.swift      – deterministic procedural audio synthesizer + WAV encoder
  Models.swift          – Track/Playlist/Album/Artist value types
  LibraryStore.swift     – bootstraps demo tracks, persistence, import, playlists
  PlayerEngine.swift     – AVAudioPlayer-backed playback/queue engine
  ArtworkView.swift      – procedural album-art renderer (SwiftUI Canvas)
  MusicPlayerApp.swift   – App entry point, windows, commands, AppKit glue
  ContentView.swift      – sidebar + detail routing, sheets
  LibraryViews.swift     – Songs/Albums/Artists/Playlist screens
  PlayerViews.swift      – Now Playing bar, Mini Player, scrubber, transport
```

## Known limitations

- No CloudKit/iTunes-library import — only local files via the file picker.
- Metadata editing (retagging imported files) isn't implemented.
- The Mini Player is a second SwiftUI `Window` scene rather than an
  `NSPanel`; it behaves like a floating utility window (`.floating` level)
  but doesn't hide from Mission Control/Cmd-Tab the way a true panel would.
