# NotchMuse Project Status

Last Updated: 2026-08-13

## Current Phase

v0.6 Multi-Player Architecture - Development Batch 1 Validation

## Current Goal

Complete real-device parity validation for the minimal Spotify Adapter and the
isolated Apple Music spike without changing the production Matcher, Provider
priority, or current public Release. The validated Provider recovery still
needs public delivery before broad expansion.

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
- Important release gap: the public `v0.3.1` tag points to `3666710`; the
  validated Provider recovery is on `main` at `8c205e3` and is not included in
  the current public DMG.

## Benchmark Health

- VPS access works through the existing local SSH key.
- Password authentication remains unavailable but is not required for current
  operations.
- `lyrics-benchmark.timer` is enabled and active.
- Natural runs `21-28` completed successfully after P0 Provider recovery.
- Coverage across runs `21-28` averages `89.38%`, with a `89.1-89.6%` range.
- Latest run: `28`, completed 2026-08-09, Coverage `892/1000` (`89.2%`).
- Run `20` baseline was `674/1000` (`67.4%`); recovery produced a sustained
  improvement of about `21.98` percentage points.
- Run `28` Provider successes: LRCLIB `628`, LRCMux `603`, NetEase `515`,
  Kugou `203`, QQ `32`, and Soda `0`.
- Run `28` unique contributions: LRCLIB `135`, LRCMux `72`, NetEase `38`,
  Kugou `10`, QQ `1`, and Soda `0`.
- Run `28` Matcher evidence: `1,215` no-candidate, `971` below-threshold, and
  `391` ambiguity-gap Provider rows.
- The Top Songs proxy reached `277/300` (`92.33%`); its first 100 reached
  `96/100` on the latest natural run.
- The latest `108` uncovered songs are concentrated in Korean (`43`), Chinese
  pop (`28`), Spotify hot (`22`), Japanese (`10`), English pop (`4`), and
  independent (`1`) tracks.

## Blocking Issues

### P0 Publish Gates

- None for `v0.3.1`; release completed and the downloaded artifact verified.

### P1 Analysis Gates

- The largest delivery blocker is that the public `v0.3.1` DMG predates the
  validated Provider recovery now present on `main`.
- Production Matcher changes remain blocked until natural run `19+` supplies
  second-candidate identity and manual ground truth proves a safe ranking
  strategy.
- Run `19` has `464` identity-equivalent and `25` non-equivalent
  ambiguity-gap provider rows. Metadata equivalence does not prove lyric text,
  timing, or version correctness.
- The `464` eligible rows remain unlabeled; correct-candidate and
  false-positive rates cannot be claimed yet.
- Title and artist normalization remain No-Go; current evidence is dominated
  by source-aligned score ties whose ground-truth lyric correctness is not
  manually labeled.
- Soda is currently unhealthy: run `28` returned `0/1000`, with all requests
  recorded as `invalid_response` JSON parse failures.
- LRCMux recorded `239` HTTP 404 responses in run `28`; no-result/endpoint
  semantics still need classification.
- LRCLIB immediate retry is not supported: second retry recovered `0/25`.
- Notch Mode can briefly switch to lyric-only height for about 1-2 seconds
  after Spotify resumes, then returns to Song + Lyric. This is a transient P1
  beta risk, not an RC blocker.
- A genuinely clean Mac/user-account Gatekeeper, TCC, Spotify, and lyrics
  journey has not yet been completed end to end.
- The current `network_error` bucket mixes HTTP 404, timeout, DNS, and parser
  failures and cannot directly justify Matcher changes.
- The Top Songs dataset is an Apple Music chart-derived proxy, not Spotify
  telemetry or real NotchMuse user telemetry.
- Public validation volume remains too small for retention conclusions: the
  repository currently has no GitHub Issues, and the `v0.3.1` DMG has only
  three recorded downloads.
- Apple Music is approved only for an isolated runtime spike; active-track,
  permission, state and timing-drift acceptance is not yet complete.
- The Batch 1 validation Mac has no authenticated playable Spotify or Apple
  Music session. Spotify parity and Apple Music two-track runtime tests remain
  incomplete; Apple Music Release integration is therefore No-Go.
- QQ Music and NetEase Cloud Music have no verified stable public macOS
  now-playing interface. Private MediaRemote and Accessibility scraping remain
  excluded from production.
- The email feedback flow is blocked from Release implementation until the
  Product Owner provides a public `FEEDBACK_EMAIL` value.
- Track Identity v1 ranking metrics remain blocked by missing frozen top-three
  candidates, stable candidate IDs, strategy-blind labels, and a holdout run.

## Completed Tasks

- Implemented the minimal `MusicPlayerAdapter`, `NowPlayingTrack`, and
  `SpotifyAdapter` boundary without rewriting `SpotifyReader` or changing the
  Matcher, Provider priority, or UI presentation.
- Added an isolated public-Apple-Events `AppleMusicAdapter` spike and verified
  state access plus response parsing; Release integration remains Conditional.
- Added Track Identity version-hint representation for offline evidence only;
  production matching does not consume it.
- Added a bilingual, user-triggered `Report Lyrics Issue…` mailto flow with no
  telemetry; delivery remains disabled behind `FEEDBACK_EMAIL`.
- Completed QQ Music and NetEase diagnostic probes; both remain production
  No-Go without a verified public scripting interface.
- Reduced the competitive UX backlog to three bounded recommendations.

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
- Deployed second-candidate evidence capture to the VPS with a code and
  database backup; 17 remote tests passed and run `18` remained `681/1000`
  (`68.1%`) after schema migration.
- Completed Lyrics Failure UX Audit and Production Stability Boundary Review.
- Built a Benchmark-only offline ranking simulator for duration, exact artist,
  album/version metadata, and bounded title-marker signals.
- Verified the simulator and Benchmark suite with `23` passing tests.
- Added a `300`-track, `300`-unique-track Top Songs proxy dataset without
  selecting by Benchmark outcome.
- Established the run `18` proxy baseline: `215/300` (`71.7%`) unweighted and
  `72.9%` user-weighted accuracy.
- Completed a copy-only review for `Finding lyrics`, `No lyrics found`, and
  generic lyrics-unavailable states; no App changes were made.
- Verified natural run `19`: timer active/enabled, service inactive, database
  snapshot hash matched the VPS, and Coverage was `644/1000` (`64.4%`).
- Verified second-candidate identity fill at `489/489` (`100%`).
- Classified run `19` ambiguity rows as `464` identity-equivalent, `25`
  non-equivalent, and `0` missing under the strict metadata key.
- Approved Benchmark-only identity-equivalent de-duplication simulation;
  production Matcher remains No-Go.
- Completed the run `19` Phase 4 simulation audit. Strict source alignment
  leaves `396` Provider rows across an upper bound of `101` failed songs; the
  300-track Top Songs proxy has `46/101` misses with at least one eligible
  duplicate pair. These are not verified recoveries.
- Audited open-source lyrics applications and source strategies. The reviewed
  projects combine LRCLIB, regional Provider endpoints, Musixmatch,
  host-specific APIs, and maintained aggregation backends; no single stable,
  free, official source solves global synced-lyrics Coverage.
- Confirmed existing Provider health and Benchmark/App parity are the next
  evidence gate. Production Provider expansion remains No-Go.
- Implemented and deployed P0 Existing Provider Recovery without changing the
  Matcher: LRCLIB skips null-duration rows, NetEase uses its plain-response
  endpoint, and LRCLIB/NetEase/Kugou remove identity-equivalent duplicates.
- Passed `26` Python tests locally and on VPS, Swift self-tests, and a Swift
  Release build.
- Replayed the nine missing tracks from the Top Songs first 100. Existing
  Providers recovered `6/9`, moving the bounded sample from `91/100` to a
  potential `97/100` with no confirmed wrong-track selection.
- Validated Provider recovery on eight natural daily runs (`21-28`), with
  average Coverage `89.38%` and no regression to the old `67%` baseline.
- Confirmed the latest natural Top Songs proxy at `277/300` (`92.33%`) and the
  first 100 at `96/100`.
- Re-ran Swift self-tests and Release build on 2026-08-09; both passed.
- Re-ran the Python Benchmark suite; all `26` tests passed.
- Completed direct source audits of LyricsX, the maintained MxIris fork,
  MusicPlayer, LyricsKit, and LyricFever without copying third-party code.
- Designed a progressive Unified Music Player Layer that first wraps the
  existing SpotifyReader and keeps LyricsClient/TrackMatcher unchanged.
- Classified Apple Music as Conditional Go for an isolated public-API spike;
  QQ Music as diagnostic-probe-only; and NetEase player integration as
  production No-Go.
- Designed the v0.6 Track Identity and offline Candidate Ranking evidence
  experiment; production Matcher remains unchanged.
- Designed a minimal bilingual, user-triggered `Report Lyrics Issue` email
  flow with no automatic upload or telemetry.

## In Progress Tasks

- Replace repository video links with GitHub native attachment URLs when
  browser upload permission is available.
- Re-capture the Status Bar screenshot without left-edge lyric cropping.
- Label eligible run `19+` candidate pairs and compare old vs experimental
  ranking in the offline simulator.
- Manually review every proposed recovery and keep confirmed false positives
  at `0`.
- Prepare a minimal hotfix Release Candidate containing the validated Provider
  recovery already on `main`.
- Investigate Soda's `0/1000` invalid-response regression without changing
  production Matcher behavior.
- Build and label a fixed sample from the remaining `108` uncovered songs.
- Classify LRCMux HTTP 404 semantics.
- Continue Benchmark-only stratified LRCLIB experiments if needed.
- Continue collecting structured GitHub beta feedback.
- Complete one real clean-Mac installation journey.
- Run the first weekly issue triage after targeted beta promotion.
- Evaluate three P1 failure-state copy changes without coupling them to Matcher
  work: `Finding lyrics`, generic unavailable guidance, and refresh guidance.
- Complete authenticated Spotify playback parity for switching, pause/resume,
  Status Bar, and Notch Mode before Release migration.
- Run the isolated Apple Music active-playback and timing-drift matrix with at
  least two playable tracks.
- Configure a public `FEEDBACK_EMAIL` and verify English and Simplified Chinese
  mail drafts before shipping the feedback entry.
- Extend Benchmark evidence with album/native ID/optional ISRC only after a
  frozen candidate data contract is approved.

## Next Decisions

- Keep the transient Notch resume layout switch as a known beta risk.
- Phase 3 second-candidate evidence extension: Completed and deployed.
- Benchmark-only ranking simulation tooling: Go.
- Benchmark-only identity-equivalent de-duplication simulation: Go for the
  `464` eligible run `19` rows; `25` non-equivalent rows stay unresolved.
- Production Matcher implementation: No-Go; no ranking strategy has yet
  improved manually verified matches with zero confirmed false positives.
- Production Provider expansion: No-Go until LRCLIB, NetEase, LRCMux, and
  Benchmark/App parity are resolved on a fixed popular-song dataset.
- P0 Existing Provider Recovery: Go; implemented and deployed.
- P0 Existing Provider Recovery validation: Passed on runs `21-28`.
- Public delivery of Provider recovery: recommend a minimal hotfix release;
  Product Owner version decision is required.
- Musixmatch official API: conditional research candidate only if recurring
  cost and licensing are accepted; reverse-engineered access is No-Go.
- Keep title/artist normalization, Provider priority changes, App retry,
  album ranking, and mandatory ISRC out of v0.5 until separate evidence gates
  pass.
- Do not add Providers or optimize for maximum aggregate Coverage.
- Keep fuzzy title, partial artist, `12s` duration tolerance, and platform
  expansion out of the current roadmap.
- Approve targeted early-beta promotion now; keep broad promotion gated on a
  clean-user journey pass and initial issue triage.
- Keep v0.4 scoped to Spotify + Apple Silicon.
- Treat Apple Music as the v0.6 second-player candidate only after an isolated
  Music.app spike proves stable playback metadata and position.
- Keep Chinese Support/Feedback translation deferred until user demand proves
  the maintenance cost is justified.
- Unified Music Player Layer: Go for a Spotify-compatible spike only.
- Apple Music: Conditional Go for isolated runtime validation; Release No-Go.
- QQ Music: Conditional Go for a diagnostic probe; production No-Go.
- NetEase Cloud Music player: production No-Go; diagnostic probe only.
- Private MediaRemote and Accessibility scraping: No-Go for production.
- Email feedback: Conditional Go; blocked on a real public feedback address.
