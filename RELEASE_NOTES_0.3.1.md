# NotchMuse v0.3.1

NotchMuse v0.3.1 is a stability and lyrics-display quality update for the
GitHub beta.

Documentation: [English README](https://github.com/Xiye88/NotchMuse#readme) ·
[简体中文](https://github.com/Xiye88/NotchMuse/blob/main/README.zh-CN.md) ·
[Setup help](https://github.com/Xiye88/NotchMuse/blob/main/SUPPORT.md)

## Highlights

- Long lyrics scroll left once, stop at the end, and reset for each new line.
- Hide Lyrics now removes the Status Bar or Notch display while keeping the
  current Spotify and lyrics state ready for Show Lyrics.
- The Notch and overlay lyrics window is click-through during normal use.
- DEBUG-only matcher decision logging improves local failure analysis without
  changing production matching behavior.
- The README now includes Status Bar Mode and Notch Mode demo videos.

## Installation

1. Download `NotchMuse.dmg`.
2. Open the DMG and drag `NotchMuse.app` into `Applications`.
3. Control-click NotchMuse and choose `Open` on first launch.
4. Allow Spotify automation access when macOS asks.
5. Look for the orange note icon in the menu bar, then open Settings to choose
   Status Bar Mode or Notch Mode.

## Unsigned macOS Notice

This beta is unsigned and not notarized. macOS may require
`System Settings > Privacy & Security > Open Anyway` during the first launch.

## Requirements

- macOS 14 or later
- Apple Silicon Mac
- Spotify desktop app

## Known Issues

- Lyrics coverage depends on third-party providers.
- Left Status Bar mode requires Accessibility permission.
- Intel Mac is not supported.
- Some menu bar organizers may hide the NotchMuse menu icon.

## Matching Scope

This release does not change matching scores, thresholds, provider order, or
retry behavior.
