# Task Completion Report

Task: 06_DOCS Release Package Report

Status: Completed

Priority: P1

## Findings

- README already explains what NotchMuse is, supported macOS version, Apple Silicon-only beta scope, Spotify requirement, install flow, Gatekeeper beta warning, permissions, privacy, source build commands, test commands, and known limitations.
- README has a `Screenshots` section, but it currently contains placeholders only.
- Installation copy is suitable for a public beta: download DMG, drag app to Applications, launch, grant Spotify Automation permission.
- Permission copy is clear and scoped:
  - Automation / Spotify: reads song, playback state, and playback position.
  - Accessibility: only needed for Left layout menu-item avoidance.
  - Network: queries public lyrics services.
- Release checklist already tracks README, CHANGELOG, screenshots, release notes, DMG upload, beta/pre-release publishing, signing, notarization, and Gatekeeper checks.
- CHANGELOG has a `0.3.0-beta - 2026-07-18` entry and enough material for GitHub Release Notes.

## Problems Found

- README screenshot placeholders are still public-facing gaps:
  - `Status Bar screenshot: pending`
  - `Notch Mode screenshot: pending`
  - `Settings screenshot: pending`
- No README position is reserved for a Demo GIF yet.
- README build example hardcodes build number `3`; release owner should confirm the final beta build number before publishing.
- CHANGELOG headings are inconsistent: `0.3.0-beta`, `0.2.2 Beta`, `0.2.1 - In Development`, and `0.2 - In Development`.
- Older CHANGELOG sections marked `In Development` may confuse public beta readers unless PM confirms they are historical internal milestones.
- Release Notes are not yet stored as a separate publish-ready draft.

## Recommended Actions

- Screenshot requirements:
  - Add screenshots directly under README `## Screenshots`.
  - Use `docs/assets/screenshots/status-bar-right.png` for Status Bar Right.
  - Use `docs/assets/screenshots/notch-mode-song-lyric.png` for Notch Mode Song + Lyric.
  - Use `docs/assets/screenshots/settings-display.png` for Settings > Display.
  - Optional: add `docs/assets/screenshots/settings-appearance.png` if visual customization is a release selling point.
  - Optional: add Left layout only if PM wants to promote Accessibility-based menu avoidance.
- Demo GIF plan:
  - Add one GIF after screenshots, before `## 使用`.
  - Suggested path: `docs/assets/demo/notchmuse-beta-demo.gif`.
  - Length: 8-12 seconds.
  - Flow: Spotify playing -> NotchMuse lyric appears -> switch Notch style or width -> lyric updates smoothly.
  - Keep desktop clean and avoid private account details.
- Installation:
  - Keep current README installation section.
  - After final signing/notarization, remove or soften the Gatekeeper beta workaround if it no longer applies.
  - Confirm the final DMG file name matches `NotchMuse.dmg`.
- Permission:
  - Keep current permission section.
  - Consider adding one sentence that Left layout can be avoided by using Right or Notch Mode if users do not want Accessibility permission.
- Release Notes draft:

```markdown
## NotchMuse 0.3.0 Beta

NotchMuse is a lightweight native macOS lyrics companion for Spotify, showing synchronized lyrics in the menu bar or notch area.

### Highlights

- Status Bar and Notch Mode lyrics display.
- Lyric Only, Song + Lyric, and Expanded Notch styles.
- Adjustable lyrics width, font size, color, animation speed, and opacity.
- English and Simplified Chinese interface.
- Lyrics matching through LRCLIB, NetEase Cloud Music, LRCMux, QQ Music, Kugou Music, and Soda Music.
- Clear install, permission, privacy, and beta limitation notes.

### Requirements

- macOS 14.0 or later.
- Apple Silicon Mac.
- Spotify desktop app.

### Beta Notes

- Intel Mac is not supported in this beta.
- Lyrics coverage depends on third-party lyrics services.
- Public DMG should be Developer ID signed and Apple notarized before publishing.
```

- CHANGELOG minimum整理:
  - Rename `0.2.2 Beta` to `0.2.2-beta - 2026-07-16` for consistency.
  - Decide whether `0.2.1 - In Development` and `0.2 - In Development` should become dated historical versions or move under `Unreleased`.
  - Keep the `0.3.0-beta - 2026-07-18` entry; it is already adequate for release prep.

## Need PM Decision

- Final tag name: `v0.3.0-beta` or another beta tag.
- Final build number for the public DMG.
- Screenshot language: English, Simplified Chinese, or both.
- Whether to show Left layout publicly despite its Accessibility permission requirement.
- Whether the Demo GIF should show Settings interaction or only the polished lyrics display.
- Whether CHANGELOG should expose older `In Development` sections or collapse them into a cleaner beta history.
