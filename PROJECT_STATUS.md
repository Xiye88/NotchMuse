# NotchMuse Project Status

Last Updated: 2026-07-26

## Current Phase

Phase 2: Post Beta Optimization

## Current Goal

Complete the final repository freeze and release artifact rebuild for
`v0.3.1` after the P0 UX fixes passed real-device validation.

## Release Status

- `v0.3.0-beta` is published as a GitHub Pre-release.
- `v0.3.1` source identifies as build `4`.
- The previous local RC DMG and SHA-256 are superseded by the P0 UX fixes and
  must not be published.
- Final RC DMG rebuild and checksum are pending the release commit.
- Repository: https://github.com/Xiye88/NotchMuse
- Release: https://github.com/Xiye88/NotchMuse/releases/tag/v0.3.0-beta
- Current support: macOS 14+, Apple Silicon, Spotify desktop app.
- Developer ID signing and notarization remain deferred.

## Benchmark Health

- VPS access works through the existing local SSH key.
- Password authentication remains unavailable but is not required for current
  operations.
- `lyrics-benchmark.timer` is enabled and active.
- Runs `6-12` completed successfully on seven consecutive days.
- Seven-day average Coverage: `66.09%`.
- Latest run: `12`, completed 2026-07-24, Coverage `68.3%`.
- Next scheduled trigger: 2026-07-25 00:00 UTC.

## Blocking Issues

### P0 Publish Gates

- The Git worktree is not frozen; implementation, documentation, templates,
  and reports still need one final scope review.
- No `v0.3.1` release commit or tag exists yet.
- The final DMG must be rebuilt from the release commit and pass clean install
  verification.

### P1 Analysis Gates

- Run `11-12` `title_mismatch` increased to `102/114`.
- `128/216` audited title mismatches are best classified as provider response
  or classification drift, not a proven normalization gap.
- Rejected candidate evidence has not yet been collected from the new DEBUG
  matcher decision logs, so title normalization remains gated.
- NetEase produced zero successes over seven days and has substantial parser
  failures; keep its production priority unchanged until a controlled provider
  decision is approved.
- LRCMux HTTP 404 responses need no-result/endpoint semantics classification.
- LRCLIB immediate retry is not supported: second retry recovered `0/25`.
- Notch Mode can briefly switch to lyric-only height for about 1-2 seconds
  after Spotify resumes, then returns to Song + Lyric. This is a transient P1
  beta risk, not an RC blocker.

## Completed Tasks

- Restored and verified read-only VPS access.
- Verified seven days of Daily Benchmark Pipeline health and SQLite history.
- Completed Benchmark Recovery and Network Error Evidence reports.
- Completed calibrated Network Failure Optimization and Matcher Upgrade
  designs without production code changes.
- Completed Title Mismatch Audit and Matcher Observability Design.
- Completed seven-day Provider Health Audit.
- Completed an isolated LRCLIB transient retry experiment.
- Completed `01_APP` implementation readiness review.
- Implemented DEBUG-only Matcher Decision Logging with no changes to matcher
  scores, thresholds, selection, Provider order, or retry behavior.
- Verified matcher logging with self-tests, Release build, and a Release binary
  boundary scan.
- Implemented v0.3.1 Lyrics Marquee UX Polish: `1.2s` delay, forward-only
  movement, endpoint clamp, timer completion, and lyric line identity reset.
- Replaced `Pause Lyrics` with `Hide Lyrics` / `Show Lyrics`; hiding now
  removes both Status Bar and Notch lyric layers while Spotify polling and
  current track state continue.
- Made the daily Notch/Overlay window permanently click-through and removed
  the incompatible `Hide on Hover` setting.
- Passed real-device critical UX smoke testing for Status Bar and Notch
  Hide/Show, hidden-state song updates, Spotify pause/resume, and a real
  click-through interaction into Spotify.
- Passed marquee self-tests, Release build, and static regression review for
  Status Bar Mode and Notch Mode.
- Completed real-device Spotify smoke testing in Status Bar Mode and Notch
  Mode with Chinese and English lyrics, song switching, and pause/resume.
- Independently verified the Matcher Decision Logging Release boundary.
- Built and verified `v0.3.1` build `4` App and DMG artifacts.
- Completed the Benchmark Failure Analysis Pipeline readiness plan.
- Added minimal GitHub Bug Report and Feature Request templates.
- Added a README Feedback section.
- Added official Status Bar and Notch Mode MP4 demos, reorganized the README
  presentation flow, and retained screenshots as visual fallback.
- Confirmed Windows, Intel, Universal Binary, and new music platforms remain
  deferred.

## In Progress Tasks

- Review and freeze the complete v0.3.1 Git diff.
- Prepare the v0.3.1 release commit and tag after repository safety review.
- Rebuild and clean-install the final DMG after the release commit.
- Replace repository video links with GitHub native attachment URLs when
  browser upload permission is available.
- Collect bounded local evidence through the new DEBUG matcher decision logs.
- Classify LRCMux HTTP 404 semantics.
- Continue Benchmark-only stratified LRCLIB experiments if needed.
- Continue collecting structured GitHub beta feedback.

## Next Decisions

- Confirm acceptance of the transient Notch resume layout switch as a known
  beta risk.
- Confirm the final release commit scope, including which internal reports
  should be tracked publicly.
- Confirm the final RC release commit, DMG rebuild, checksum, and tag sequence.
- Decide when to run a DEBUG-only, local, bounded plaintext candidate sampling
  session for manual title mismatch audits.
- Keep Title normalization, Provider priority changes, and App retry out of
  the current release until evidence review is complete.
- Keep fuzzy title, partial artist, `12s` duration tolerance, and platform
  expansion out of the current roadmap.
