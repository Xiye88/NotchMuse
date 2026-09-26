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
  <a href="https://notchmuse.com"><strong>Website</strong></a> · <a href="https://github.com/Xiye88/NotchMuse/releases/download/v0.8.0-beta.2/NotchMuse.dmg"><strong>Download v0.8.0 Beta 2</strong></a>
  ·
  <a href="https://github.com/Xiye88/NotchMuse/issues">Report an issue</a>
</p>

<p align="center">
  macOS 14+ · Apple Silicon · Spotify · Apple Music · NetEase Cloud Music · QQ Music · Soda Music
</p>

> **Public beta:** [v0.8.0-beta.2](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.0-beta.2), build 31. Supports all five players, Auto Detect, and redesigned bilingual Settings. Includes a refreshed installer, bilingual first-open guide, and Privacy & Security shortcut. Ad-hoc signed, not notarized. Download directly from [notchmuse.com](https://notchmuse.com).

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

| **Player detection** | **Notch Mode** |
| --- | --- |
| Detects active playback from Spotify, Apple Music, NetEase Cloud Music, QQ Music, and Soda Music. Auto Detect is the default; you can select a player manually. | Choose Lyric Only, Song + Lyric, or Expanded layouts near the notch. |
| **Bundled playback bridge** | **Private by design** |
| The MediaRemote bridge is included; no Homebrew installation is needed. NetEase, QQ Music, and Soda Music rely on macOS private MediaRemote APIs and may need updates after macOS or player changes. | No account, telemetry, or audio upload. English and Simplified Chinese are built in. |

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

Redesigned Settings includes a sidebar, live Status Bar/Notch previews, appearance presets, and display controls. The screenshot below is from an earlier version.

![Settings](docs/assets/screenshots/settings-window.png)

## Quick Start

The public v0.8.0 Beta 2 supports Spotify, Apple Music, NetEase Cloud Music, QQ Music, and Soda Music.

1. Visit [notchmuse.com](https://notchmuse.com) or [download the Beta 2 DMG directly](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.0-beta.2/NotchMuse.dmg).
2. Open the DMG and drag `NotchMuse.app` to `Applications`.
3. Because this beta is not notarized, Control-click `NotchMuse.app`, choose `Open`, then confirm `Open`.
4. Open any of the five supported desktop players and play a song.
5. Keep Auto Detect selected or choose your player in Settings. Allow Automation for Spotify or Apple Music when prompted.
6. Look for the orange note icon in the menu bar.
7. Use Settings to choose Status Bar Mode or Notch Mode.

## Installation

### Requirements

- macOS 14.0 or later
- Apple Silicon Mac
- Spotify, Apple Music, NetEase Cloud Music, QQ Music, or Soda Music desktop app

The current beta is `arm64` only. Intel Macs are not supported.

The beta bundles its MediaRemote bridge; no separate Homebrew or helper installation is required. NetEase, QQ Music, and Soda Music use private macOS MediaRemote APIs, which may change after system or player updates.

1. Download the versioned DMG from [the website](https://notchmuse.com).
2. Open the DMG.
3. Drag `NotchMuse.app` into `Applications`.
4. Open NotchMuse from `Applications`.
5. When macOS asks for permission to control the selected music player, allow it.

### Beta Signing Notice

This GitHub beta is ad-hoc signed, but it is not signed with Apple Developer ID or notarized. macOS may ask you to confirm the first launch.

To open it:

1. In Finder, open `Applications`.
2. Control-click `NotchMuse.app`.
3. Choose `Open`.
4. Confirm `Open` again.

If macOS still blocks it, go to `System Settings > Privacy & Security` and choose `Open Anyway` for NotchMuse.

Developer ID signing and Apple notarization remain deferred. This is a public testing beta.

If installation, Gatekeeper, music player Automation permission, or lyrics lookup fails, see [SUPPORT.md](SUPPORT.md).

## Optional Menu Bar Setup

NotchMuse does not require a menu bar organizer. If your menu bar is already crowded, an optional tool such as Ice, Thaw, or Bartender can free up space for Status Bar Mode.

## Known Issues

- The beta is not signed with Apple Developer ID or notarized, so macOS Gatekeeper warnings are expected.
- Lyrics coverage depends on third-party providers.
- NetEase, QQ Music, and Soda Music depend on private macOS MediaRemote APIs and may need compatibility updates.
- Word-by-word lyrics are not guaranteed; most providers return line-level timing.
- Left Status Bar mode requires Accessibility permission.
- Other menu bar management tools may hide the NotchMuse icon.
- Intel Mac is not supported in the current beta.

## Roadmap

- Current public beta: v0.8.0-beta.2, five players, Auto Detect, Settings UI v2, and refreshed installer
- Next: clean-device validation and fixes based on real Beta feedback
- Future distribution and compatibility work will follow validation

## Usage

1. Open Spotify, Apple Music, NetEase Cloud Music, QQ Music, or Soda Music and play a song.
2. Open NotchMuse.
3. Lyrics appear in the menu bar or notch area.
4. Use the menu bar note icon to open the control menu.
5. Keep Auto Detect selected or manually choose one of the five players. Open Settings to change display and appearance preferences.

If a menu bar organizer hides the NotchMuse icon, expand hidden menu bar items or open NotchMuse again to bring the menu back.

## Permissions

- Automation / Spotify or Apple Music: reads current track, playback state, and playback position.
- NetEase Cloud Music, QQ Music, and Soda Music: read playback metadata through the bundled private MediaRemote bridge.
- Accessibility: only needed for the left Status Bar layout so NotchMuse can avoid active app menu items.
- Network: queries public lyrics providers for the current song.

## Feedback

For setup help, read [SUPPORT.md](SUPPORT.md). For feedback, read [FEEDBACK.md](FEEDBACK.md), then use [GitHub Issues](https://github.com/Xiye88/NotchMuse/issues). Choose **Bug report** for reproducible problems and **Feature request** for focused use cases or improvements.

## Privacy

- No NotchMuse account is required.
- NotchMuse does not read or upload audio from any supported player.
- NotchMuse does not collect telemetry, usage analytics, or personal profiles.
- Track title, artist, album, and duration may be sent to third-party lyrics providers for matching.
- Settings are stored locally with `UserDefaults`.

## For Developers

Architecture, build and test instructions, Lyrics Quality Benchmark, Evidence Gate, Matcher design, and provider analysis are collected in [Developer Documentation](docs/README.md).

## License

NotchMuse is released under the MIT License. Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The beta bundles the BSD-3-Clause-licensed MediaRemote Adapter bridge; its pinned source revision and attribution are documented in the third-party notices. No Homebrew install is required.
