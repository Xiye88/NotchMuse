# NotchMuse Roadmap

Last Updated: 2026-09-22

## Current — v0.8 Candidate Stability + UX Polish Sprint

Status: ACTIVE / NOT RELEASED

Goal: move the existing Spotify, Apple Music, and NetEase candidate from
feature completion to production-quality behavior and a verified release
candidate.

### P0.1 — Single Installed Version

Status: DONE

- Inventory all installed and Spotlight-visible NotchMuse app bundles.
- Keep one primary build-15 candidate and recoverably archive older installed
  copies.
- Verify one launch entry, one running process, shared bundle identity, helper
  lifecycle, and retained preferences.

Exit criteria: the user cannot accidentally launch an older NotchMuse build.

Result: only `/Applications/NotchMuse.app` build `15` remains installed and
Spotlight-visible. Old build 7 and build 14 copies are recoverably archived in
Trash; preferences remain intact and Auto Detect is selected.

### P0 — Player Ownership and Settings

Status: IMPLEMENTED / AUTOMATED CHECKS PASS

- Make Auto Detect the recommended default player mode.
- Detect Spotify (`com.spotify.client`), Apple Music (`com.apple.Music`), and
  NetEase (`com.netease.163music`).
- Keep explicit player overrides for all three players.
- Restore the missing NetEase Settings option and add regression coverage for
  the complete enum/UI/datasource/adapter path.
- On player exit, hide lyrics by default and wait for recovery; offer an option
  to keep the final lyric visible and paused.

Exit criteria: deterministic owner selection, no stale lyric after owner or
track changes, all four Settings choices persist, and regression checks pass.

### P1 — Lyrics State and Notch UX

Status: IMPLEMENTED / REAL-PLAYER AND GUI QA PENDING

- Playing: show lyrics and scroll.
- Paused: retain lyrics and stop scrolling.
- Stopped: apply the configured hide-or-hold policy.
- Track change: clear the old lyric before loading the new lyric.
- Default to lyric-only presentation with no background.
- Support Background `None / Black / Custom`.
- Support Hide lyrics on hover `ON / OFF`, defaulting to ON.

Exit criteria: automated state checks and focused GUI regression pass across
Spotify, Apple Music, and NetEase.

### P2 — v0.8 Release Candidate

Status: LOCAL BUILD 15 VERIFIED / RELEASE GATES PENDING

- Run automated tests, real-player smoke tests, lifecycle checks, and a clean
  install gate proportionate to release risk.
- Build and verify the DMG and checksum.
- Verify and document signing/notarization truthfully.
- Synchronize `PROJECT_STATUS.md`, `TASK_BOARD.md`, `ROADMAP.md`, CHANGELOG,
  and release notes after the implementation and QA evidence land.
- Obtain Product Owner confirmation immediately before public push/tag/release.

Current local artifact: `0.8.0` build `15`, SHA-256
`215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
It is arm64 and ad-hoc signed; Gatekeeper rejects it. Real-player, lifecycle,
Notch GUI, and clean-install gates remain.

Exit criteria: a reproducible verified RC with a recorded GO, CONDITIONAL GO,
or NO-GO decision. This roadmap does not claim the RC is complete.

## Future — Website Distribution

Status: PLANNED / NOT IN DEVELOPMENT

After v0.8, plan `notchmuse.com` with a landing page, download page, and release
notes. Host only the DMG, checksum, and `latest.json`; do not upload source code
to the website.

## Completed Milestones

- v0.3.x: open-source beta and initial lyrics UX.
- v0.4-v0.5: evidence pipeline and bounded Provider recovery.
- v0.6.0-v0.6.1: Spotify and Apple Music production support, published.
- v0.7-v0.7.1: Matcher and metadata evidence gates completed with NO-GO for
  Production behavior changes.
- v0.8 candidate groundwork: bundled NetEase bridge, adapter, lifecycle work,
  and local build-14 artifact completed; no public v0.8 release was made.

## Product Guardrails

- Do not modify Production Matcher, thresholds, ranking, or Provider priority
  without a new independent evidence gate.
- Do not treat Provider hits as proof of visible, synchronized lyrics.
- Do not claim signing, clean-install, or public-release completion without
  direct verification.
- Do not start website implementation during the v0.8 sprint.
