# NotchMuse Project Status

Last Updated: 2026-08-17

## Current Phase

v0.6.0 Release Candidate

## Current Goal

Publish the verified Apple Music integration without changing the production
Matcher, Provider order, retry, threshold, or normalization behavior.

## Release Status

- `v0.3.0-beta` is published as a GitHub Pre-release.
- `v0.3.1` build `4` is published as a GitHub Pre-release.
- `v0.6.0` build `6` Release Candidate is generated and verified.
- `v0.6.0` DMG SHA-256:
  `770b80446b58d114e04af3dfa9016f3794ce607dedf1d2653dbebcb4b73b38d9`.
- Release commit: `3666710`.
- Release tag: `v0.3.1`.
- DMG SHA-256:
  `f8b0efe34ebb361509c0c6e861edd754e4c64a8eb1f0b24ddb7bf22474fcedb0`.
- The DMG was downloaded again from GitHub; SHA-256 matched and
  `hdiutil verify` passed.
- Repository: https://github.com/Xiye88/NotchMuse
- Release: https://github.com/Xiye88/NotchMuse/releases/tag/v0.3.1
- Apple Music production integration is GO for `v0.6.0`: authenticated
  playback, both display modes, pause/resume, song switching, app restart,
  Automation denial/re-grant, stale-lyric clearing, and Spotify regression pass.
- Current support: macOS 14+, Apple Silicon, Spotify or Apple Music.
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
- Latest verified run: `32`, completed 2026-08-13, Coverage `889/1000`
  (`88.9%`).
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
- Apple Music production routing and the five-song runtime matrix pass on the
  current v0.6 build. Automation denial clears stale lyrics and shows recovery
  guidance; re-grant restores current lyrics without restarting NotchMuse.
- Authenticated-player validation on 2026-08-14 covered two English tracks, two
  Chinese tracks, and one complex `with` metadata track. All five completed the
  Apple Music Adapter, LyricsClient, and Status Bar chain with current lyrics.
  Notch Mode, pause/resume, song switching, stale-lyric clearing, and NotchMuse
  restart also passed. When Music.app exposed no current track, NotchMuse safely
  showed `Waiting for Apple Music`; manually resuming playback restored lyrics.
- Spotify core parity passes on the same v0.6 build: `Cruel Summer` rendered
  current Notch lyrics, switching to `After Hours` replaced the title and lyric,
  and build 6 recovered the same Spotify lyric after a player-source restart.
- English and `zh-Hans` Release self-tests pass. The local Swift 6.3.3 compiler
  builds cleanly against the installed macOS 15.4 SDK; build 6 is ad-hoc signed
  with minimum macOS 14.0.
- QQ Music and NetEase Cloud Music have no verified stable public macOS
  now-playing interface. Private MediaRemote and Accessibility scraping remain
  excluded from production.
- Track Identity Dataset v1 is frozen from natural run `32`, but ranking metrics
  remain blocked by `0/2,568` human-label coverage, missing candidate album and
  ISRC, and no third-or-later frozen candidates.

## Completed Tasks

- Wired Apple Music into the production `MusicPlayerAdapter` selection path
  with Spotify as the unchanged default. The selected player now feeds the
  existing LyricsClient, Status Bar and Notch display path without Matcher or
  Provider changes.
- Added a bilingual Music Player setting, player-neutral connection states,
  Automation recovery guidance, stale-lyric clearing, and a generation guard
  that prevents an old Adapter response from overwriting a newly selected
  player.
- Verified Swift self-tests, localized strings, ad-hoc signed Release build,
  and public Apple Events access to Music.app. Music.app returned `stopped` and
  no local test tracks, so this is implementation evidence rather than the
  required five-song runtime evidence.
- Completed partial authenticated Apple Music runtime validation: real
  metadata, play/pause/resume, seek, position advance, multiple song changes,
  stale-lyric clearing, Status Bar rendering, Notch rendering, and NotchMuse
  restart all behaved correctly while Music.app had an active queue.
- Completed the five-song Apple Music runtime matrix on the current v0.6 build:
  `She Is My Sin`, `Fire`, `稻香`, `爱你没差`, and `等你下课 (with 杨瑞代)`
  all rendered current lyrics. Spotify core regression also passed with
  `Cruel Summer` and a switch to `After Hours`.
- Completed the Automation denial/re-grant gate: denial removed the current
  lyric and showed permission guidance while Music.app continued playing;
  re-grant restored synchronized lyrics without restarting NotchMuse.
- Accepted the Music.app restart policy for v0.6: NotchMuse clears stale lyrics
  while Music has no current track and recovers after playback resumes.
- Isolated status self-tests from the selected UI language and passed both
  English and Simplified Chinese Release-binary self-tests.
- Finalized the public Feedback Email configuration at one build location using
  `ztongxue3@gmail.com`; English, Chinese, song/no-song, Spotify/Apple Music,
  default Mail Client, Cancel, and Send paths passed. Status: READY.
- Froze Track Identity Dataset v1 from natural run `32`: `2,568` failed cases,
  SHA-256 `b0bbb940...ffca6d9d`, with explicit Apple Music catalog-proxy source
  labeling and `27/27` Python tests passing.
- Completed Batch 2 Candidate Ranking review. Human-label denominator is zero,
  so accuracy/false-positive/ambiguity/no-result deltas are not computable and
  production ranking remains No-Go.
- Reconfirmed QQ Music and NetEase player adapters as production No-Go.
- Selected the v0.6 UX Top 3: failure-state clarity, conditional temporary
  offset, and Restore Defaults.
- Implemented the minimal `MusicPlayerAdapter`, `NowPlayingTrack`, and
  `SpotifyAdapter` boundary without rewriting `SpotifyReader` or changing the
  Matcher, Provider priority, or UI presentation.
- Added an isolated public-Apple-Events `AppleMusicAdapter` spike and verified
  state access plus response parsing; Release integration remains Conditional.
- Added Track Identity version-hint representation for offline evidence only;
  production matching does not consume it.
- Added a bilingual, user-triggered `Report Lyrics Issue…` mailto flow with no
  telemetry; the public recipient is configured and delivery status is READY.
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
- Exercise Apple Music Automation denial and re-grant on a disposable user
  account or after explicit approval to change the macOS security permission.
- Decide whether Music.app restart must preserve playback, or whether the safe
  Waiting state plus manual replay recovery is acceptable for v0.6.
- Blind-label a stratified Track Identity v1 sample before rerunning ranking.

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
- Keep broader Chinese Support documentation deferred; App feedback UI and
  email drafts are already bilingual.
- Unified Music Player Layer: Go for a Spotify-compatible spike only.
- Apple Music: Conditional Go for isolated runtime validation; Release No-Go.
- QQ Music: Conditional Go for a diagnostic probe; production No-Go.
- NetEase Cloud Music player: production No-Go; diagnostic probe only.
- Private MediaRemote and Accessibility scraping: No-Go for production.
- Email feedback: READY with Product Owner-approved public address.
