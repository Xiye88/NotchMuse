# NotchMuse Roadmap

Last Updated: 2026-09-25 — v0.8.0 build 18

## Current — v0.8 Stability Fix Sprint (build 18 frozen candidate)

Status: FROZEN / READY FOR RELEASE REVIEW

Goal: move the existing Spotify, Apple Music, and NetEase candidate from
feature completion to production-quality behavior and a verified release
candidate.

### P0.1 — Single Installed Version

Status: DONE

- Inventory all installed and Spotlight-visible NotchMuse app bundles.
- Keep one primary build-18 candidate and recoverably archive older installed
  copies.
- Verify one launch entry, one running process, shared bundle identity, helper
  lifecycle, and retained preferences.

Exit criteria: the user cannot accidentally launch an older NotchMuse build.

Result: only `/Applications/NotchMuse.app` build `18` is the installed candidate and
Spotlight-visible. Historical build 7 and 14 records are retained in handoff; preferences remain intact and Auto Detect is selected.

### P0 — Player Ownership and Settings

Status: DONE — build 18 Auto Detect final GUI PASS

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

Status: DONE — Product Owner confirms final GUI PASS

- Playing: show lyrics and scroll.
- Paused: retain lyrics and stop scrolling.
- Stopped: apply the configured hide-or-hold policy.
- Track change: clear the old lyric before loading the new lyric.
- Default to lyric-only presentation with no background.
- Support Background `None / Black / Custom`.
- Support Hide lyrics on hover `ON / OFF`, defaulting to ON.

Exit criteria: automated state checks and focused GUI regression pass across
Spotify, Apple Music, and NetEase.

Current build 18 evidence: Product Owner final GUI PASS covers Notch/current/restart
lyrics, custom-color persistence, Hide on Hover, Auto Detect combinations and
ownership/fallback/stale clearing, Sleep/Wake, and network recovery. Exact steps
and durations were not supplied.

### P2 — v0.8 Release Candidate

Status: FROZEN / READY FOR RELEASE REVIEW

- Completed build 18 Debug/Release builds and self-tests, real-player and
  lifecycle checks, final GUI confirmation, and a 60-minute playback soak.
- Built and verified the arm64 DMG and SHA-256; documented ad-hoc signing and
  its distribution limitations.
- Synchronized status, handoff, task board, roadmap, changelog, and closure
  evidence. Ready for release review; public distribution remains separate.

Current local artifact: `0.8.0` build `18`, arm64, ad-hoc signed. Executable SHA-256
`4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`; DMG SHA-256
`4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`. All current
stability, playback, GUI, lifecycle, package, and soak gates are recorded PASS.
The candidate is FROZEN / READY FOR RELEASE REVIEW. Ad-hoc signing, Gatekeeper
rejection, notarization, and clean-new-user distribution assessment remain
known release-review risks. This status does not authorize public release.

## Future — Website Distribution

Status: PLANNED / NOT IN DEVELOPMENT

After v0.8, plan `notchmuse.com` with a landing page, download page, and release
notes. Host only the DMG, checksum, and `latest.json`; do not upload source code
to the website.

## Next — 10_SETTINGS_UI

Status: QUEUED / NOT STARTED

The approved Settings UI redesign is the next implementation task after v0.8
Final Engineering closes. It must start from the latest stable Architecture
SHA and follow `NotchMuse_Settings_UI_Redesign_PM_Handoff.md` without reopening
the visual direction. No Settings UI work is part of the current phase.

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
