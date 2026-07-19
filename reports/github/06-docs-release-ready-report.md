# Task Completion Report

Task: 06_DOCS Release Ready Report

Status: Completed

Priority: P0

## Findings

- README now matches the GitHub Open Source Beta direction: unsigned DMG is documented, macOS Control-click `Open` and `System Settings > Privacy & Security > Open Anyway` are covered, and Developer ID / notarization is correctly deferred to a future Distribution Phase.
- README already covers product summary, feature list, system requirements, installation, usage, permissions, privacy, source build commands, tests, known limitations, and third-party notices.
- Installation section is release-usable for an unsigned open source beta.
- Permission section is clear and minimal: Spotify Automation, Left-layout Accessibility, and network access for lyrics lookup.
- Known Issues are partly covered under `## 已知限制`.
- `RELEASE_CHECKLIST.md` has been updated to track unsigned Gatekeeper warning, Control-click Open, and Open Anyway validation.
- CHANGELOG has a `0.3.0-beta - 2026-07-18` entry suitable as a base for GitHub Release Notes.
- LICENSE and THIRD_PARTY_NOTICES exist. THIRD_PARTY_NOTICES includes the Apache 2.0 reference project and local Apache license text is present.

## Problems Found

- README still has screenshot placeholders only:
  - `Status Bar screenshot: pending`
  - `Notch Mode screenshot: pending`
  - `Settings screenshot: pending`
- README does not yet include a Demo GIF slot or path.
- README does not yet include an Architecture section. This is important for an open source package because users need to understand the native AppKit/SPM structure before contributing.
- Known Issues are present as limitations, but the section could be renamed or expanded for GitHub readers.
- CHANGELOG headings remain inconsistent:
  - `0.3.0-beta - 2026-07-18`
  - `0.2.2 Beta - 2026-07-16`
  - `0.2.1 - In Development`
  - `0.2 - In Development`
- README build example still hardcodes build number `3`; final beta build number needs confirmation.
- Release Notes are not yet stored as a standalone draft or pasted into GitHub Releases.

## Recommended Actions

- README final版建议:
  - Keep the current README structure; do not rewrite broadly.
  - Add a short `## Architecture` section after `## 使用` or before `## 从源码构建`.
  - Replace screenshot placeholders only after assets exist.
  - Add one Demo GIF line under Screenshots only after the GIF exists.
  - Rename `## 已知限制` to `## Known Issues / 已知限制` if the public release page should be bilingual.
- Suggested Architecture copy:

```markdown
## Architecture

NotchMuse is a native macOS AppKit app built with Swift Package Manager.

- `SpotifyReader` reads the current Spotify track and playback position through macOS Automation.
- `LyricsClient` queries multiple lyrics providers and selects synchronized lyrics.
- `TrackMatcher` keeps provider matches conservative to avoid wrong live/remix/acoustic versions.
- `LyricClock`, `LyricParser`, and `ScrollState` drive timed lyric display and long-line scrolling.
- `MenuBarController` manages the status bar entry and control menu.
- `OverlayLyricsWindow` renders the top-center / notch lyrics overlay.
- `SettingsWindowController` manages Display, Appearance, and General settings.
- `AccessibilityManager` is used only when Left status bar positioning needs menu-item avoidance.
```

- Screenshot清单:
  - `docs/assets/screenshots/status-bar-right.png`: Status Bar Right with Spotify playing.
  - `docs/assets/screenshots/notch-mode-song-lyric.png`: Notch Mode Song + Lyric.
  - `docs/assets/screenshots/notch-mode-expanded.png`: optional, if PM wants to show the fuller mode.
  - `docs/assets/screenshots/settings-display.png`: Settings > Display.
  - `docs/assets/screenshots/settings-appearance.png`: optional, if customization is important.
  - Skip Left layout screenshot unless PM wants to explain the Accessibility permission path.
- Demo GIF需求:
  - Path: `docs/assets/demo/notchmuse-beta-demo.gif`.
  - README position: directly below screenshots, before `## 使用`.
  - Length: 8-12 seconds.
  - Flow: Spotify playing -> lyrics appear -> switch Notch style or width -> lyric updates smoothly.
  - Use clean desktop, hide private account details, and prefer English UI unless PM chooses bilingual assets.
- Installation说明:
  - Keep current DMG install steps.
  - Keep unsigned macOS warning and both launch paths:
    - Finder Control-click `NotchMuse.app` -> `Open`.
    - `System Settings > Privacy & Security` -> `Open Anyway`.
  - Keep Developer ID / notarization as future Distribution Phase only.
- Known Issues:
  - Keep third-party lyrics coverage warning.
  - Keep line-level timing limitation.
  - Keep Left layout Accessibility/menu-bar-manager limitation.
  - Add unsigned beta warning if PM wants Known Issues to mirror Installation.
- Release Notes draft:

```markdown
## NotchMuse 0.3.0 Beta

NotchMuse is a lightweight native macOS lyrics companion for Spotify. This open source beta focuses on menu bar and notch-area synchronized lyrics for Apple Silicon Macs.

### Highlights

- Status Bar and Notch Mode lyrics display.
- Lyric Only, Song + Lyric, and Expanded Notch styles.
- Adjustable width, font size, color, animation speed, and opacity.
- English and Simplified Chinese interface.
- Lyrics matching through LRCLIB, NetEase Cloud Music, LRCMux, QQ Music, Kugou Music, and Soda Music.
- Local settings storage with no NotchMuse account or telemetry.

### Installation Notes

- Download `NotchMuse.dmg`, open it, and drag `NotchMuse.app` to Applications.
- This GitHub Open Source Beta is unsigned. macOS may block the first launch.
- To open it, Control-click `NotchMuse.app`, choose `Open`, then confirm. If needed, use `System Settings > Privacy & Security > Open Anyway`.
- Allow Spotify Automation permission when prompted.

### Requirements

- macOS 14.0 or later.
- Apple Silicon Mac.
- Spotify desktop app.

### Known Issues

- Intel Mac is not supported in this beta.
- Lyrics coverage depends on third-party lyrics services.
- Timing is primarily line-level, not word-level.
- Left Status Bar layout requires Accessibility permission and may be affected by menu bar management tools.

### Distribution

Developer ID signing and Apple notarization are planned for a future Distribution Phase.
```

- CHANGELOG最小整理:
  - Change `0.2.2 Beta - 2026-07-16` to `0.2.2-beta - 2026-07-16`.
  - Move `0.2.1 - In Development` and `0.2 - In Development` under `Unreleased` or convert them to dated historical entries after PM confirms the history.
  - Keep the `0.3.0-beta - 2026-07-18` entry.

## Need PM Decision

- Final GitHub tag: confirm `v0.3.0-beta`.
- Final build number for `NotchMuse.dmg`.
- Screenshot language: English, Simplified Chinese, or both.
- Whether README should be bilingual throughout or keep the current mixed English/Chinese structure.
- Whether to include Left layout in public screenshots despite the Accessibility permission requirement.
- Whether Demo GIF should show Settings interaction or only the polished lyrics surface.
- Whether to apply the minimal README Architecture/Known Issues edits now or wait until screenshots and GIF are ready.
- Whether to clean CHANGELOG now or preserve current internal milestone history.
