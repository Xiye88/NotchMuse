# NotchMuse Project Status

Last Updated: 2026-07-30

## Current Phase

v0.5 Lyrics Matching Accuracy - Phase 3: Evidence Completion

## Current Goal

Capture second-candidate identity for ambiguous Benchmark decisions, then
decide whether a bounded candidate de-duplication simulation is supported.
Keep production matching behavior, Provider scope, Spotify integration, and
Apple Silicon support unchanged until Phase 4 Go/No-Go.

## Release Status

- `v0.3.0-beta` is published as a GitHub Pre-release.
- `v0.3.1` build `4` is published as a GitHub Pre-release.
- Release commit: `3666710`.
- Release tag: `v0.3.1`.
- DMG SHA-256:
  `f8b0efe34ebb361509c0c6e861edd754e4c64a8eb1f0b24ddb7bf22474fcedb0`.
- The DMG was downloaded again from GitHub; SHA-256 matched and
  `hdiutil verify` passed.
- Repository: https://github.com/Xiye88/NotchMuse
- Release: https://github.com/Xiye88/NotchMuse/releases/tag/v0.3.1
- Current support: macOS 14+, Apple Silicon, Spotify desktop app.
- Developer ID signing and notarization remain deferred.

## Benchmark Health

- VPS access works through the existing local SSH key.
- Password authentication remains unavailable but is not required for current
  operations.
- `lyrics-benchmark.timer` is enabled and active.
- Runs `17-18` completed naturally after rejected-candidate evidence reporting
  was deployed.
- Latest run: `18`, completed 2026-07-30, Coverage `68.1%`.
- Latest seven-day average Coverage: `68.34%`.
- Run `18` Matcher evidence: `3,786` matching failures, `2,602`
  candidate-backed, `1,184` no-candidate, `1,412` below-threshold, and `1,190`
  ambiguity-gap rows.
- Candidate evidence coverage: `68.73%`.
- Next scheduled trigger: 2026-07-31 00:00 UTC.

## Blocking Issues

### P0 Publish Gates

- None for `v0.3.1`; release completed and the downloaded artifact verified.

### P1 Analysis Gates

- Production Matcher changes remain blocked until the Phase 3 experiment and
  Phase 4 Go/No-Go complete.
- `224/319` run `18` failed songs have a source-aligned top candidate rejected
  in a score tie, but the second candidate identity is not yet stored.
- Equal scores do not prove identity-equivalent candidates or equal lyric text
  and timing. Candidate de-duplication simulation remains conditional.
- Title and artist normalization remain No-Go; current evidence is dominated
  by source-aligned score ties whose second candidate identity is unknown.
- NetEase produced zero successes over seven days and has substantial parser
  failures; keep its production priority unchanged until a controlled provider
  decision is approved.
- LRCMux HTTP 404 responses need no-result/endpoint semantics classification.
- LRCLIB immediate retry is not supported: second retry recovered `0/25`.
- Notch Mode can briefly switch to lyric-only height for about 1-2 seconds
  after Spotify resumes, then returns to Song + Lyric. This is a transient P1
  beta risk, not an RC blocker.
- A genuinely clean Mac/user-account Gatekeeper, TCC, Spotify, and lyrics
  journey has not yet been completed end to end.
- The current `network_error` bucket mixes HTTP 404, timeout, DNS, and parser
  failures and cannot directly justify Matcher changes.

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
- Published `v0.3.1` from release commit `3666710` with DMG and checksum
  assets.
- Re-downloaded and verified the GitHub release DMG.
- Completed the Phase 2 Benchmark health check: latest Coverage `68.9%`,
  seven-run average `67.16%`.
- Completed the v0.4 Matcher roadmap with an Evidence Gate and zero
  false-positive requirement.
- Confirmed Windows, Intel, Universal Binary, and new music platforms remain
  deferred.
- Completed the Public Beta GitHub growth and feedback audits.
- Added `FEEDBACK.md` and linked it from README.
- Prepared targeted X, Reddit, and GitHub early-beta announcement drafts.
- Confirmed English-default and manually selectable Simplified Chinese UI
  coverage without creating a second localization system.
- Completed a 60-case Failure Taxonomy sample from verified runs `8-14`.
- Classified LRCMux as healthy with unresolved 404/no-result semantics,
  LRCLIB as mixed Network/Parser/Matcher, and NetEase as unhealthy.
- Confirmed the Matcher Evidence Gate can run without new code changes.
- Added `SUPPORT.md` and prepared the v0.4 Early Beta promotion package.
- Completed the v0.5 priority review; Apple Music is the first conditional
  candidate, while Universal Binary requires demand and Intel QA hardware.
- Added a full Simplified Chinese README with an English/Chinese switch.
- Added bilingual Quick Start instructions and first-screen support
  requirements.
- Verified live VPS runs `15-16`; the latest Coverage is `68.4%`.
- Confirmed title and artist normalization remain No-Go until candidate-backed
  evidence exists.
- Implemented Benchmark-only rejected candidate evidence capture without
  changing App or Benchmark match selection behavior.
- Verified evidence capture with 16 unit tests, 1,000 legacy/new matcher parity
  cases, an existing-DB migration check, and a live title-mismatch smoke test.
- Deployed rejected candidate evidence capture to the VPS with a code backup,
  passing remote tests, compatible production SQLite migration, and unchanged
  systemd timer configuration.
- Added English, Simplified Chinese, and Support links plus the menu bar entry
  point to the v0.3.1 Release Notes.
- Added structured rejected-candidate evidence aggregation to Benchmark
  `latest.json` and `latest.md`, excluding non-Matcher provider failures.
- Deployed Matcher evidence reporting to the VPS; 17 remote tests passed and
  run `16` backward-compatibility output was verified.
- Verified natural runs `17-18`; run `18` Coverage is `68.1%` and candidate
  evidence coverage is `68.73%`.
- Created an 80-row, 80-song stratified v0.5 failure dataset from run `18`.
- Completed v0.5 Failure Analysis and Matcher Improvement Proposal.
- Confirmed production Matcher is No-Go and approved a Benchmark-only
  second-candidate identity evidence extension.
- Implemented the evidence extension locally with 17 tests, 1,000 decision
  parity cases, and a compatible production-DB-copy migration.
- Completed Lyrics Failure UX Audit and Production Stability Boundary Review.

## In Progress Tasks

- Replace repository video links with GitHub native attachment URLs when
  browser upload permission is available.
- Re-capture the Status Bar screenshot without left-edge lyric cropping.
- Review and deploy the Phase 3 second-candidate evidence extension.
- Validate second-candidate metadata density after the next natural run.
- Only if top and second identities are equivalent, run the bounded
  de-duplication simulation and manually review every proposed recovery.
- Classify NetEase response/parser failure separately from Matcher failures.
- Classify LRCMux HTTP 404 semantics.
- Continue Benchmark-only stratified LRCLIB experiments if needed.
- Continue collecting structured GitHub beta feedback.
- Complete one real clean-Mac installation journey.
- Run the first weekly issue triage after targeted beta promotion.
- Evaluate three P1 failure-state copy changes without coupling them to Matcher
  work: `Finding lyrics`, generic unavailable guidance, and refresh guidance.

## Next Decisions

- Keep the transient Notch resume layout switch as a known beta risk.
- Phase 3 second-candidate evidence extension: Approved.
- Candidate de-duplication simulation: Conditional; blocked until second
  candidate identity evidence exists.
- Production Matcher implementation: No-Go pending Phase 4.
- Keep title/artist normalization, Provider priority changes, App retry,
  album ranking, and mandatory ISRC out of v0.5 until separate evidence gates
  pass.
- Do not add Providers or optimize for maximum aggregate Coverage.
- Keep fuzzy title, partial artist, `12s` duration tolerance, and platform
  expansion out of the current roadmap.
- Approve targeted early-beta promotion now; keep broad promotion gated on a
  clean-user journey pass and initial issue triage.
- Keep v0.4 scoped to Spotify + Apple Silicon.
- Treat Apple Music as a v0.5 candidate only after a Music.app AppleScript
  evidence spike proves stable playback metadata and position.
- Keep Chinese Support/Feedback translation deferred until user demand proves
  the maintenance cost is justified.
