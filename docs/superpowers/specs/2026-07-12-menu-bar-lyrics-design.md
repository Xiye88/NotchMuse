# Menu Bar Lyrics Design

## Goal

Build a small native macOS app that shows the current Spotify lyric line across the top menu bar area. Short lyrics stay still. Long lyrics scroll inside a fixed-width overlay.

## MVP Scope

- Show a small menu bar item for controls and a top menu bar overlay for the current lyric line.
- Read Spotify's current track, artist, playback state, and playback position from the local Spotify macOS app.
- Fetch synced lyrics from LRCLIB by track name, artist name, album name when available, and duration when available.
- Update the displayed lyric line while Spotify plays.
- Scroll lyric text horizontally when it is longer than the chosen menu bar width.
- Provide a small menu with:
  - Pause/Resume Lyrics
  - Width: Small, Medium, Large
  - Refresh Lyrics
  - Quit

## Out of Scope for MVP

- No floating Dynamic Island window.
- No WPS deployment or WPS integration.
- No Spotify Web API login.
- No lyric editing.
- No cloud sync.
- No installer package.
- No support for non-Spotify players.

## Platform

- macOS app written in Swift using AppKit.
- Target: Apple Silicon MacBook first.
- Minimum macOS: macOS 14 unless Xcode or local SDK requires a newer setting.

## Architecture

The app is a menu bar/accessory app. It has no Dock icon and no main window.

Components:

- `SpotifyReader`: reads current Spotify state through AppleScript.
- `LyricsClient`: calls LRCLIB search/get APIs and returns synced lyric lines.
- `LyricParser`: parses LRC timestamp lines into timed lyric entries.
- `LyricClock`: maps Spotify playback position to the current lyric line.
- `MenuBarController`: owns the menu bar item, menu actions, width setting, and scrolling display.
- `OverlayLyricsWindow`: shows the lyric in the top menu bar area.

## Data Flow

1. Every second, `SpotifyReader` checks Spotify state.
2. If the track changed, `LyricsClient` fetches synced lyrics for the new track.
3. `LyricParser` parses synced lyrics into timestamped lines.
4. `LyricClock` selects the current line using Spotify playback position.
5. `MenuBarController` displays that line.
6. If the line is too wide, `MenuBarController` scrolls it by advancing an offset timer.

## Display Behavior

- Default text when Spotify is closed: `Open Spotify`
- Default text when Spotify is paused: last lyric line prefixed with `Paused: `
- Default text when no synced lyrics are found: `No synced lyrics`
- Default text while loading: `Loading lyrics...`
- Width choices:
  - Small: 420 px
  - Medium: 720 px
  - Large: 980 px
- Long lyric scrolling:
  - Wait briefly at the start.
  - Scroll left at a steady speed.
  - Pause briefly at the end.
  - Loop.

## Error Handling

- If Spotify is not running, show `Open Spotify`.
- If AppleScript cannot read Spotify, show `Spotify unavailable`.
- If LRCLIB request fails, keep the previous lyric until the track changes or the user refreshes.
- If no synced lyric is found, show `No synced lyrics`.
- Network failures do not crash the app.

## Testing

Keep tests small and local:

- `LyricParser` parses timestamped LRC lines.
- `LyricClock` picks the correct current line for a playback time.
- Scroll offset logic wraps correctly for long text.

Manual verification:

- Start Spotify and play a common English song.
- Confirm the menu bar lyric updates.
- Confirm long lines scroll.
- Pause Spotify and confirm pause text.
- Change songs and confirm lyrics refresh.
- Quit Spotify and confirm fallback text.

## Project Structure

Create a minimal Swift Package executable first. If local tooling requires an Xcode app target for menu bar UI, generate the smallest Xcode project that wraps the same source files.

Planned structure:

```text
MenuBarLyrics/
  Package.swift
  Sources/MenuBarLyrics/
    AppDelegate.swift
    SpotifyReader.swift
    LyricsClient.swift
    LyricParser.swift
    LyricClock.swift
    MenuBarController.swift
    OverlayLyricsWindow.swift
  Tests/MenuBarLyricsTests/
    LyricParserTests.swift
    LyricClockTests.swift
    ScrollStateTests.swift
```

## Acceptance Criteria

- The app launches as a menu bar item.
- It does not show a Dock icon.
- It reads the currently playing Spotify track.
- It fetches synced lyrics when available.
- It displays the current lyric line in the menu bar.
- It scrolls lyric text when the line is longer than the selected width.
- The menu supports pause/resume, width switching, manual refresh, and quit.
- Parser and lyric timing tests pass.

## Deferred

- Floating Dynamic Island mode can be added after the menu bar version works.
- Local cached lyrics can be added if repeated network fetches become annoying.
- Spotify Web API can be added if AppleScript proves unreliable.
- WPS deployment can be revisited only if there is a concrete reason to run this through WPS.
