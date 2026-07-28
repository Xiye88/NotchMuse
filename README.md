<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

<h1 align="center">NotchMuse</h1>

<p align="center">
  <strong>A native macOS app that brings synced lyrics to your menu bar and notch.</strong>
  <br>
  Lyrics where you need them, without interrupting your workflow.
</p>

<p align="center">
  <a href="https://github.com/Xiye88/NotchMuse/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/Xiye88/NotchMuse?include_prereleases&label=release"></a>
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&logoColor=white">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/Xiye88/NotchMuse"></a>
</p>

<p align="center">
  <a href="https://github.com/Xiye88/NotchMuse/releases/tag/v0.3.1"><strong>Download the latest beta</strong></a>
  ·
  <a href="https://github.com/Xiye88/NotchMuse/issues">Report an issue</a>
</p>

<p align="center">
  macOS 14+ · Apple Silicon · Spotify desktop app required
</p>

## Quick Start

Before you start: NotchMuse currently requires macOS 14 or later, an Apple Silicon Mac, and the Spotify desktop app.

1. Download `NotchMuse.dmg` from [GitHub Releases](https://github.com/Xiye88/NotchMuse/releases/tag/v0.3.1).
2. Open the DMG and drag `NotchMuse.app` to `Applications`.
3. Because this is an unsigned beta, Control-click `NotchMuse.app`, choose `Open`, then confirm `Open`.
4. Open Spotify and play a song.
5. Allow macOS Automation when NotchMuse asks to control Spotify.
6. Look for the orange note icon in the menu bar.
7. Use Settings to choose Status Bar Mode or Notch Mode.

## Demo

### Status Bar Mode

Lyrics stay visible in the macOS menu bar while you use other apps.

[![Status Bar Mode demo](docs/assets/demos/notchmuse-status-bar-demo.gif)](docs/assets/demos/notchmuse-status-bar-demo.mp4)

### Notch Mode

Song information and synchronized lyrics appear below the MacBook notch.

[![Notch Mode demo](docs/assets/demos/notchmuse-notch-mode-demo.gif)](docs/assets/demos/notchmuse-notch-mode-demo.mp4)

## Why NotchMuse?

- Keep synchronized lyrics visible while working in other apps.
- Choose a compact menu bar display or a MacBook notch layout.
- Stay native and lightweight, with no NotchMuse account or telemetry.

## Features

| **Menu Bar lyrics** | **Notch-native display** |
| --- | --- |
| Keep Spotify-synchronized lyrics on the left or right side of the menu bar. | Choose Lyric Only, Song + Lyric, or Expanded layouts near the notch. |
| **Native and private** | **Fits your workspace** |
| No account, telemetry, or audio upload. English and Simplified Chinese are built in. | Target built-in or external displays and adjust width, color, type size, animation, and opacity. |

## Screenshots

### Full Mac Context

NotchMuse stays visible in a real macOS workspace while Spotify is playing.

![NotchMuse in a macOS workspace](docs/assets/screenshots/full-mac-context.png)

### Status Bar Mode

Synced lyrics stay visible in the macOS menu bar while you work in other apps.

![Status Bar Mode](docs/assets/screenshots/status-bar-mode.png)

### Notch Mode

Lyrics appear near the MacBook notch in a compact, glanceable layout.

![Notch Mode](docs/assets/screenshots/notch-mode-crop.png)

### Settings

Choose the display mode and adjust width, color, font size, animation speed, opacity, and startup behavior.

![Settings](docs/assets/screenshots/settings-window.png)

## Installation

### Requirements

- macOS 14.0 or later
- Apple Silicon Mac
- Spotify desktop app for macOS

The current beta build is `arm64` only. Intel Mac and Universal Binary support are planned for a later phase.

1. Download `NotchMuse.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `NotchMuse.app` into `Applications`.
4. Open NotchMuse from `Applications`.
5. When macOS asks for permission to control Spotify, allow it.

### Unsigned Beta Notice

This GitHub beta is distributed as an unsigned macOS build. macOS may ask you to confirm the first launch because the app is not signed with Apple Developer ID yet.

To open it:

1. In Finder, open `Applications`.
2. Control-click `NotchMuse.app`.
3. Choose `Open`.
4. Confirm `Open` again.

If macOS still blocks it, go to `System Settings > Privacy & Security` and choose `Open Anyway` for NotchMuse.

Developer ID signing and Apple notarization are deferred to a future Distribution Phase.

If installation, Gatekeeper, Spotify permission, or lyrics lookup fails, see [SUPPORT.md](SUPPORT.md).

## Optional Menu Bar Setup

NotchMuse does not require a menu bar organizer. If your menu bar is already crowded, an optional tool such as Ice, Thaw, or Bartender can free up space for Status Bar Mode.

## Known Issues

- The beta is unsigned, so macOS Gatekeeper warnings are expected.
- Lyrics coverage depends on third-party providers.
- Word-by-word lyrics are not guaranteed; most providers return line-level timing.
- Left Status Bar mode requires Accessibility permission.
- Other menu bar management tools may hide the NotchMuse icon.
- Intel Mac is not supported in the current beta.

## Roadmap

- v0.4: lyrics matching quality and provider health
- Later: signed distribution and broader Mac compatibility

## Usage

1. Open Spotify and play a song.
2. Open NotchMuse.
3. Lyrics appear in the menu bar or notch area.
4. Use the menu bar note icon to open the control menu.
5. Open Settings to change display mode, position, color, width, font size, animation speed, opacity, and launch behavior.

If a menu bar organizer hides the NotchMuse icon, expand hidden menu bar items or open NotchMuse again to bring the menu back.

## Permissions

- Automation / Spotify: reads current track, playback state, and playback position.
- Accessibility: only needed for the left Status Bar layout so NotchMuse can avoid active app menu items.
- Network: queries public lyrics providers for the current song.

## Architecture

NotchMuse is a native Swift macOS menu bar app.

- `AppDelegate` owns app startup, single-instance behavior, Settings, and lifecycle coordination.
- `SpotifyReader` reads current Spotify playback through macOS automation.
- `LyricsClient` queries lyrics providers and returns synchronized lyrics.
- `MenuBarController` renders Status Bar lyrics.
- `OverlayLyricsWindow` renders Notch Mode lyrics.
- `SettingsWindowController` manages user preferences.
- `lyrics-provider-benchmark/` is an external benchmark lab used to measure provider coverage and matching quality.

The benchmark lab does not run inside the app. Its role is to identify provider and matching issues for future optimization.

## Lyrics Quality

The current benchmark lab tests a 1,000-track dataset against multiple lyrics providers.

Latest available snapshot:

- Dataset: `extended_1000`
- Successful matches: `684/1000`
- Coverage: `68.4%`
- Providers tested: LRCMux, LRCLIB, QQ Music, Soda Music, Kugou, NetEase

Known failure categories include network errors, artist mismatch, title mismatch, and version mismatch. Coverage depends on third-party services and should be treated as a quality snapshot, not a guarantee for every song.

## Build From Source

```sh
./scripts/build_app.sh
./scripts/build_dmg.sh
./scripts/build_release.sh 0.3.1 4
```

Build output:

```text
dist.noindex/NotchMuse.app
dist.noindex/NotchMuse.dmg
```

The default GitHub beta build is unsigned/ad-hoc signed. A future Developer ID build can be generated with:

```sh
NOTCHMUSE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_dmg.sh
```

Manual release steps are tracked in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Test

```sh
swift run --package-path MenuBarLyrics NotchMuse --self-test
./scripts/run_live_matrix.sh
```

## Feedback

For setup help, read [SUPPORT.md](SUPPORT.md). For feedback, read [FEEDBACK.md](FEEDBACK.md), then use [GitHub Issues](https://github.com/Xiye88/NotchMuse/issues). Choose **Bug report** for reproducible problems and **Feature request** for focused use cases or improvements.

## Privacy

- No NotchMuse account is required.
- NotchMuse does not read or upload Spotify audio.
- NotchMuse does not collect telemetry, usage analytics, or personal profiles.
- Track title, artist, album, and duration may be sent to third-party lyrics providers for matching.
- Settings are stored locally with `UserDefaults`.

## License

NotchMuse is released under the MIT License. Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
