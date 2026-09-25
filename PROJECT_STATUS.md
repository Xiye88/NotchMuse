# NotchMuse Project Status

Last Updated: 2026-09-25 — v0.8.0 build 18

## Current Status

- NetEase: DONE for the v0.8 candidate.
- MediaRemote Bridge: DONE for the v0.8 candidate.
- Auto Detect: DONE for Spotify, Apple Music, and NetEase.
- v0.8 Candidate: FROZEN / READY FOR RELEASE REVIEW.
- Product Owner final GUI confirmation: PASS. Individual GUI steps and timing
  values were not supplied; none are inferred here.
- No merge to main, push, tag, or public release has been performed by this
  closure task.

## Candidate Identity

- Version/build: `0.8.0` build `18`.
- Candidate Freeze commit:
  `3fb6946602dd35308d201fe7d5e609e63ebcb42e`.
- Freeze commit parent / audited startup baseline:
  `dee834f533812aac3e1dcab83f5d62a008d6a906`.
- Executable SHA-256:
  `4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`.
- DMG: `dist.noindex/NotchMuse.dmg`; SHA-256
  `4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`.
- Architecture: arm64. Signing: ad-hoc, no Team ID. Developer ID signing,
  notarization, and stapling are not included in this candidate.

## Completed Gates

- Debug and Release builds and self-tests: PASS.
- Localization key parity: 102 English / 102 Simplified Chinese, exact parity.
- `git diff --check`: PASS.
- `codesign --verify --deep --strict`: PASS; `hdiutil verify`: PASS.
- Product Owner confirms build 18 seek forward/back, Notch Mode/current and
  restart lyrics, custom color persistence, Hide on Hover, Auto Detect player
  combinations/ownership/fallback/stale clearing, Sleep/Wake, and network
  recovery: Manual PASS. No unprovided steps or latency values are asserted.
- Continuous-playback soak: 60 minutes, PASS for playback and helper stability;
  three checkpoints and multiple advancing playback/track observations, with
  one app, watchdog, and Perl stream process and no crash/restart/orphan.

## Known Risks and Release Review

- The candidate is ad-hoc signed and has no Team ID; Gatekeeper rejects it.
  Developer ID signing, notarization, stapling, and clean-new-user install
  assessment remain release-review/distribution work.
- The manual GUI confirmation was supplied as a consolidated PASS without
  per-step artifacts or exact durations. The closure report preserves that
  evidence level without inventing details.
- `Production Matcher`, thresholds, ranking, and Provider priority remain
  frozen; no changes to them are part of this sprint.

## Historical Evidence

Build 7, 14, 15, 16, and 17 observations are historical only. The current
status above is based on build 18 closure. Prior backup Git sync and install
snapshots remain in `PROJECT_HANDOFF.md` as historical evidence.
