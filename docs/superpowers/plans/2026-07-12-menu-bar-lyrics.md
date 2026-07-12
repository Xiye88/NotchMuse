# Menu Bar Lyrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that shows synced Spotify lyrics and scrolls long lines.

**Architecture:** A Swift Package executable imports AppKit and runs as an accessory menu bar app. Spotify state is read with AppleScript, LRCLIB provides synced lyrics, and small pure Swift helpers handle LRC parsing, lyric timing, and scroll offsets.

**Tech Stack:** Swift 6.3, AppKit, Foundation URLSession, AppleScript through `osascript`, Swift Package Manager.

## Global Constraints

- Do not require full Xcode; use Swift Package Manager and command line tools.
- Do not add third-party dependencies.
- Keep the first version Spotify-only.
- No WPS/VPS integration for this native desktop MVP.
- Produce a runnable `.app` bundle under `dist/`.

---

### Task 1: Pure Lyric Logic

**Files:**
- Create: `MenuBarLyrics/Package.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/LyricParser.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/LyricClock.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/ScrollState.swift`
- Create: `MenuBarLyrics/Tests/MenuBarLyricsTests/LyricParserTests.swift`
- Create: `MenuBarLyrics/Tests/MenuBarLyricsTests/LyricClockTests.swift`
- Create: `MenuBarLyrics/Tests/MenuBarLyricsTests/ScrollStateTests.swift`

**Interfaces:**
- Produces: `LyricLine`, `LyricParser.parse(_:)`, `LyricClock.currentLine(at:in:)`, `ScrollState.offset(...)`.

- [x] Write parser, clock, and scroll tests.
- [x] Implement the smallest pure Swift helpers.
- [x] Run `swift test`.

### Task 2: Spotify and LRCLIB Integration

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/SpotifyReader.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/LyricsClient.swift`

**Interfaces:**
- Produces: `SpotifyTrack`, `SpotifyReader.read() async -> SpotifyState`, `LyricsClient.syncedLyrics(for:) async throws -> [LyricLine]`.

- [x] Implement Spotify AppleScript reader.
- [x] Implement LRCLIB fetch and parse.
- [x] Add small parsing tests where useful.

### Task 3: Menu Bar App

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/main.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/AppDelegate.swift`
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`

**Interfaces:**
- Consumes: `SpotifyReader`, `LyricsClient`, `LyricClock`, `ScrollState`.
- Produces: running menu bar app with Pause/Resume, width choices, Refresh, Quit.

- [x] Create accessory AppKit app.
- [x] Render a fixed-width menu bar item.
- [x] Poll Spotify and lyrics.
- [x] Scroll long lyric lines.

### Task 4: Bundle and Verify

**Files:**
- Create: `scripts/build_app.sh`
- Create: `dist/MenuBarLyrics.app`
- Create: `README.md`

- [x] Build the executable.
- [x] Package a no-Dock `.app`.
- [x] Run tests.
- [x] Verify bundle structure.
