# Task Completion Report

Task: GitHub Release Package Report

Status: Completed

Priority: P1

## Findings

- README is release-oriented and covers product summary, core features, macOS requirements, Apple Silicon-only beta scope, installation, Gatekeeper warning, permissions, privacy, source build commands, tests, known limitations, and third-party notices.
- README still has screenshot placeholders for Status Bar, Notch Mode, and Settings.
- Release checklist exists at `RELEASE_CHECKLIST.md` and tracks product, macOS permission, packaging, signing, notarization, DMG, and GitHub release steps.
- CHANGELOG exists and includes `0.3.0-beta - 2026-07-18` with release-preparation changes.
- LICENSE exists and uses MIT License.
- THIRD_PARTY_NOTICES exists and documents Lyricify Lyrics Helper as an Apache 2.0 reference, including project URL, copyright, reference commit, and no-binary-dependency statement.
- Apache 2.0 license text exists at `LICENSES/Apache-2.0.txt`.
- A local DMG exists at `dist.noindex/NotchMuse.dmg`, but this report did not verify signing, notarization, stapling, Gatekeeper behavior, checksum, or GitHub upload readiness.

## Problems Found

- README screenshots are still marked `pending`; this is the main visible blocker for a polished public GitHub release page.
- README does not include direct visual assets or links for screenshots/GIFs yet.
- README build example uses build number `3`; release checklist uses `<build>`. PM/release owner should confirm the final public build number before publishing.
- CHANGELOG version naming is inconsistent: `0.3.0-beta`, `0.2.2 Beta`, `0.2.1 - In Development`, and `0.2 - In Development`.
- CHANGELOG has older in-development sections after beta entries; public readers may not know whether those items shipped, were superseded, or remain historical planning notes.
- Release notes are not yet separated into a GitHub-ready publish draft.
- No screenshot inventory or demo GIF capture plan exists as a standalone checklist.
- LICENSE copyright holder is `Carlos`; PM should confirm whether this should remain personal or use a project/company name.
- THIRD_PARTY_NOTICES covers the known Apache 2.0 reference, but there is no final dependency/service notice checklist confirming every lyrics provider and bundled asset has been reviewed.

## Recommended Actions

- Capture and add these screenshots before publishing:
  - Status Bar Right layout with live synced lyric and Spotify playing.
  - Status Bar Left layout only if Accessibility positioning is a public selling point.
  - Notch Mode Lyric Only.
  - Notch Mode Song + Lyric.
  - Notch Mode Expanded.
  - Settings > Display.
  - Settings > Appearance.
  - First-launch permission or onboarding screen if available and stable.
- Keep the README screenshot section small: replace the three `pending` bullets with embedded images or links once assets exist.
- Prepare one short demo GIF:
  - Duration: 8-12 seconds.
  - Flow: Spotify playing -> NotchMuse shows lyric -> switch Notch style or width -> lyric updates/scrolls.
  - Capture target: built-in display, clean desktop, English UI unless PM wants bilingual marketing.
  - Avoid showing private Spotify account details or unrelated menu bar items.
- Use this GitHub Release Notes draft for `0.3.0-beta`:

```markdown
## NotchMuse 0.3.0 Beta

This beta prepares NotchMuse for public GitHub distribution as an Apple Silicon macOS app.

### Highlights

- Native macOS menu bar lyrics companion for Spotify.
- Status Bar and Notch Mode display options.
- Lyric Only, Song + Lyric, and Expanded Notch styles.
- Adjustable lyrics width, font size, color, animation speed, and opacity.
- English and Simplified Chinese UI.
- Lyrics matching through LRCLIB, NetEase Cloud Music, LRCMux, QQ Music, Kugou Music, and Soda Music.
- Clear permission and privacy notes in the README.

### Beta Notes

- Requires macOS 14.0 or later.
- Apple Silicon only for this beta.
- Spotify desktop app is required.
- Lyrics coverage depends on third-party lyrics services.
- Public release DMG should be Developer ID signed and Apple notarized.
```

- Normalize CHANGELOG headings before public release. Suggested minimal structure:
  - `## 0.3.0-beta - 2026-07-18`
  - `## 0.2.2-beta - 2026-07-16`
  - `## 0.2.1 - 2026-07-xx` or move to an `Unreleased` section if not shipped.
  - `## 0.2.0 - 2026-07-xx` or move to an `Unreleased` section if not shipped.
- Add a checksum to the GitHub release body after producing the final DMG.
- Run the existing release checklist before publishing and mark each GitHub item complete.

## Need PM Decision

- Final public version tag: confirm whether GitHub tag should be `v0.3.0-beta`.
- Final build number for the public DMG.
- Screenshot language: English only, Simplified Chinese only, or both.
- Whether to include the Left Status Bar Accessibility-dependent layout in public screenshots.
- Whether the demo GIF should show Settings changes or only the polished lyrics experience.
- Copyright holder in LICENSE: keep `Carlos` or change to a formal project/company name.
- Whether THIRD_PARTY_NOTICES should mention public lyrics services as service notices in addition to code/license references.
