# NotchMuse Roadmap

Last Updated: 2026-07-25

## Phase 1: GitHub Open Source Beta Release

Status: Completed

- Published `v0.3.0-beta` with a verified DMG and SHA-256.
- Current support remains macOS 14+, Apple Silicon, and Spotify desktop app.

## Phase 2: Lyrics Quality and Stability

### v0.3.1 - Lyrics Quality Improvement + UX Polish

Status: Release Candidate validated; repository freeze pending.

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

Remaining:

- Freeze the repository and create the v0.3.1 release commit.
- Rebuild the DMG from the frozen commit and publish the checksum.
- Record the transient Notch resume layout switch as a beta known issue.
- Use bounded local candidate metadata sampling to obtain evidence for future
  title normalization.
- Classify LRCMux HTTP 404 semantics.
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

Goal: Establish the Failure Analysis Pipeline, then improve matching without
increasing false positives.

Order:

1. Parse and import DEBUG matcher logs into the existing Benchmark SQLite.
2. Run a controlled 50-100 track audit and establish the failure taxonomy.
3. Use the captured evidence to audit rejected candidates.
4. Add title or artist normalization only when logs prove a safe gap.
5. Continue provider-specific experiments in Benchmark.
6. Reconsider App retry only after a stratified experiment shows second
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

### v0.5 - Lyrics Quality Hardening

Goal: Consolidate proven quality improvements and provider health knowledge.

Candidates:

- Provider health classification and reporting.
- Stable failure taxonomy and trend reporting.
- Confidence-scoring experiments in Benchmark only.
- Confirmed UX and display compatibility bug fixes.
- Release hardening based on real GitHub feedback.

Deferred:

- Windows.
- Intel Mac.
- Universal Binary.
- Apple Music and all other new music platforms.
- App Store distribution.

## Product Guardrails

- Lyrics Quality and stability take priority over expansion.
- Benchmark evidence precedes production changes.
- Coverage gains never justify confirmed wrong matches.
- One small batch is implemented and validated at a time.
