# NotchMuse Project Status

Last Updated: 2026-09-26 — v0.8 Final Engineering

## Final Engineering Status

- `09_REPO_ARCHITECTURE`: DONE / ARCHIVED on
  `codex/repository-architecture-cleanup` at
  `d5673b9b5b9e25baff4abb57db2264f30ace19c2`.
- Remote Architecture branch: synchronized; final CI run `36157250718` PASS.
- Integrated into `main` with merge commit
  `7bc74acd9abe8f6c4b5eb185b3dd5dd51c273ff0`.
- Main documentation head `dbdd422f95178ffb5466e8c9f7304ddb1b3cc52c`
  is synchronized to `origin/main`; CI run `36158606048` PASS.
- Repository structure, Swift package tests, GitHub CI, bilingual README,
  report indexes, and build artifact manifests: DONE.
- Final integrated artifact: `0.8.0` build `20`, arm64, ad-hoc signed,
  not notarized. DMG SHA-256:
  `0aa060361f5566bcfcb34fe4bde9c17e7d8a08dd1fcbf9fbb22226c32f8b05e3`.
- `10_SETTINGS_UI`: DONE. The isolated implementation branch ends at
  `5d74ce67ad25dfd9fa1c0a036cc4f06d05772575`; CI run `36213755351` passed.
  The implementation was integrated into main as `279b910` without changing
  player, Matcher, Provider, or release behavior.
- Developer ID/notarization/stapling: DEFERRED. v0.8.0 tag and GitHub Release:
  NOT AUTHORIZED; awaiting a separate Product Owner release decision.

## Current Status

- NetEase: DONE for the v0.8 candidate.
- MediaRemote Bridge: DONE for the v0.8 candidate.
- Auto Detect: DONE for Spotify, Apple Music, and NetEase.
- v0.8 Candidate: FINAL RC / READY FOR RELEASE DECISION.
- Product Owner final GUI confirmation: PASS. Individual GUI steps and timing
  values were not supplied; none are inferred here.
- Final Engineering is integrated into `main`. No v0.8 tag, GitHub Release, or
  public website release has been created.

## Candidate Identity

- Version/build: `0.8.0` build `20`.
- Candidate implementation commit: `279b910` plus the final project-document
  synchronization commit.
- Executable SHA-256:
  `7c52681e81f99d8f77f4778ec2926d334b4d28d0081e8bed4acdc4cc14340334`.
- DMG: `dist.noindex/NotchMuse.dmg`; SHA-256
  `0aa060361f5566bcfcb34fe4bde9c17e7d8a08dd1fcbf9fbb22226c32f8b05e3`.
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
