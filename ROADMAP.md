# NotchMuse Roadmap

Last Updated: 2026-08-13

## Phase 1: GitHub Open Source Beta Release

Status: Completed

- Published `v0.3.0-beta` with a verified DMG and SHA-256.
- Current support remains macOS 14+, Apple Silicon, and Spotify desktop app.

## Phase 2: Lyrics Quality and Stability

### v0.3.1 - Lyrics Quality Improvement + UX Polish

Status: Released as GitHub Pre-release on 2026-07-26.

Goal: Add safe matcher observability and complete the targeted lyrics UX fix.

Completed:

- Restored VPS access through SSH key authentication.
- Verified seven healthy daily Benchmark runs.
- Established a seven-day Coverage baseline of `66.09%`.
- Audited 216 title mismatch failures from run `11-12`.
- Completed seven-day Provider Health analysis.
- Completed an isolated LRCLIB retry experiment; App retry is No-Go.
- Designed Matcher Decision Logging and passed implementation readiness
  review.
- Implemented and verified DEBUG-only Matcher Decision Logging.
- Confirmed Release builds contain no matcher diagnostic event strings.
- Implemented forward-only marquee behavior with a `1.2s` delay and endpoint
  stop.
- Completed real-device Spotify smoke tests in Status Bar and Notch modes.
- Built and verified the local `0.3.1` build `4` DMG.
- Designed the minimum Benchmark Failure Analysis Pipeline.
- Added GitHub Bug Report and Feature Request templates.
- Added a README Feedback entry point.
- Published release commit `3666710` and tag `v0.3.1`.
- Published and re-downloaded the final DMG; SHA-256 and `hdiutil verify`
  passed.
- Added official Status Bar and Notch Mode MP4 demos.

Post-release:

- Keep the transient Notch resume layout switch as a beta known issue.
- Replace Demo links with native GitHub attachments when upload permission is
  available.
- Re-capture the Status Bar screenshot without left-edge lyric cropping.
- Keep collecting real beta issues and environment data.

Exit Criteria:

- Matcher decisions can be reproduced from DEBUG logs.
- Release builds emit no candidate metadata.
- Self-tests, Release build, App launch, DMG verification, and real Spotify
  smoke tests pass.
- Repository is clean and the artifact is built from the release commit.
- Title normalization remains unchanged.
- Provider priority and App retry remain unchanged.

### v0.4 - Safe Lyrics Quality Improvement

Status: Evidence foundation completed.

Goal: Establish the Failure Analysis Pipeline, then improve matching without
increasing false positives.

Order:

1. Complete the Evidence Gate using DEBUG-only candidate decision logs.
2. Separate Provider Health failures from matcher failures.
3. Parse and import DEBUG matcher logs into the existing Benchmark SQLite.
4. Run a controlled 50-100 track audit and establish the failure taxonomy.
5. Use the captured evidence to audit rejected candidates.
6. Add title or artist normalization only when logs prove a safe gap.
7. Continue provider-specific experiments in Benchmark.
8. Reconsider App retry only after a stratified experiment shows second
   attempt recovery greater than zero.

Validation Gate:

- Swift self-test passes.
- 100-track live matrix passes.
- 1000-song Benchmark comparison uses the same dataset.
- Confirmed false positives remain `0`.
- p95 latency increase remains within `500ms`.
- HTTP 403/429 does not increase.

Explicitly Excluded:

- Broad generic retry.
- Current LRCLIB App retry.
- Provider priority changes based on Benchmark ranking.
- Fuzzy title matching by default.
- Partial-artist acceptance.
- Relaxing duration tolerance to `12s`.
- Global provider reordering from aggregate ranking.

### v0.5 - Lyrics Matching Accuracy

Goal: Improve real matching accuracy through bounded evidence while confirmed
false positives remain zero.

Phases:

1. Phase 1 - Failure Analysis: completed with natural runs `17-18` and an
   80-song stratified failure dataset.
2. Phase 2 - Matcher Improvement Proposal: completed; production Matcher is
   No-Go.
3. Phase 3 - Evidence Completion and Bounded Validation: completed; second
   candidate identity capture is deployed for natural run `19+`.
4. Phase 4 - Matcher Optimization Simulation: in progress. The Benchmark-only
   simulator and Top Songs proxy baseline are ready. Natural run `19` supplied
   complete second identity for `489/489` ambiguity rows; `464` strict
   identity-equivalent rows may enter Benchmark-only simulation. Production
   remains No-Go pending labeled evidence and manual review.
5. Phase 4.1 - Existing Provider Recovery: completed and validated. LRCLIB,
   NetEase, and Kugou parser/endpoint/duplicate-candidate defects were repaired
   without changing Matcher acceptance. Runs `21-28` average `89.38%`
   Coverage, compared with `67.4%` on run `20`.
6. Phase 4.2 - Remaining Coverage Evidence: in progress. Classify Soda's
   invalid responses, LRCMux 404 semantics, and a labeled sample from the
   remaining `108` misses before any new Provider or Matcher proposal.
7. Phase 4.3 - Public Delivery: pending Product Owner version decision. The
   recovery code is on `main` but is not included in the public `v0.3.1` DMG.

Validation Gate:

- Use the same run `18` dataset and failure pool.
- Do not change score, threshold, Provider order, retry, or normalization.
- Prove top and second candidate identity before counting any duplicate pool.
- Report recovery count only from confirmed identity-equivalent pairs.
- Manually review every proposed recovery.
- Confirmed false positives remain `0`.
- Benchmark simulation latency increase remains negligible.
- At least one ranking strategy improves manually verified
  correct-candidate rate without increasing confirmed false positives.

Explicitly Excluded:

- New Providers.
- Aggregate Coverage maximization as a goal.
- Production Matcher changes before Phase 4 approval.
- Title or artist normalization in the current experiment.
- Album as an acceptance override.
- Mandatory ISRC identity.
- Provider priority changes without a separate Provider Health decision.

Deferred:

- Windows.
- QQ Music and NetEase Cloud Music.
- Intel Mac / Universal Binary without hardware and demand evidence.
- Apple Music production integration; its evidence spike moves to v0.6.
- App Store distribution.

### v0.6 - Multi-Player Architecture and Evidence

Status: Research complete; isolated spikes pending.

Goal: Add a maintainable player boundary without regressing Spotify, then use
new metadata as evidence rather than immediately changing production matching.

Order:

1. Publish the already validated Provider recovery.
2. Wrap SpotifyReader with a neutral adapter and prove exact behavior parity.
3. Run an isolated Apple Music Apple Events spike.
4. User-triggered email feedback: completed with the approved public address.
5. Capture and label Track Identity evidence in Benchmark.
6. Run QQ Music and NetEase diagnostic probes only on current installed apps.
7. Consider a second production player only after the first two adapters pass.

Go / No-Go:

- Unified adapter boundary: Go for Spike.
- Apple Music: Conditional Go for Spike; Release No-Go pending runtime matrix.
- QQ Music: diagnostic-only Conditional Go; production No-Go.
- NetEase player: production No-Go; diagnostic-only evidence allowed.
- Track Identity ranking: Benchmark-only Go; production Matcher No-Go.
- Email feedback: Ready; public recipient configured in one build location.

Explicitly Excluded:

- Shipping three new players together.
- Private MediaRemote in the Release binary.
- Accessibility/UI scraping as a playback backend.
- New lyrics Providers.
- Production Matcher changes without labeled holdout evidence.
- Large UI redesign, Windows, Intel-first work, or automatic telemetry.

## Product Guardrails

- Lyrics Quality and stability take priority over expansion.
- Benchmark evidence precedes production changes.
- Coverage gains never justify confirmed wrong matches.
- One small batch is implemented and validated at a time.
