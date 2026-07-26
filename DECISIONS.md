# NotchMuse Decisions

## 2026-07-26 - v0.3.1 Release and v0.4 Entry Gate

- Publish `v0.3.1` as an unsigned GitHub Pre-release for macOS 14+ on Apple
  Silicon.
- Keep the transient Notch pause/resume layout switch as a beta known issue,
  not a release blocker.
- Keep internal Task Completion Reports containing local paths or VPS
  endpoints out of the public release commit.
- Start v0.4 with an Evidence Gate and Provider Health Classification.
- Do not implement title or artist normalization until candidate-backed
  Benchmark simulation shows zero confirmed false positives.
- Do not change provider order, matching thresholds, duration tolerance, or
  App retry based only on aggregate Coverage.

Last Updated: 2026-07-24

## Decision Log

### 2026-07-18: Enter Phase 1 Beta Release Freeze

Decision: Stop feature development until GitHub Beta Release Candidate is ready.

Reason:
- The app is functionally close to beta.
- Release quality now depends on signing, notarization, clean install QA, and public documentation.
- New features would increase release risk.

### 2026-07-18: Treat Developer ID signing and notarization as release blockers

Decision: Do not publish the public GitHub beta with an ad-hoc signed app.

Reason:
- QA found `spctl` rejects the current app.
- Public macOS downloads need Developer ID signing and notarization for normal user trust.

### 2026-07-18: Keep Benchmark optimization out of Phase 1

Decision: Lyrics Provider Benchmark findings move to Phase 2 unless they expose a Critical/High release issue.

Reason:
- Phase 1 priority is stable beta release.
- Matcher changes can create wrong-lyrics regressions.
- Current live matrix passed the release threshold.

### 2026-07-18: Do not relax App matcher to fuzzy title matching during Freeze

Decision: Keep Swift matcher conservative for beta.

Reason:
- Fuzzy title and partial artist matching can increase false positives.
- Benchmark may explore these rules, but App runtime needs stronger safety.

### 2026-07-18: Defer Intel Mac and Universal Binary

Decision: Keep `0.3.0-beta` Apple Silicon only.

Reason:
- Existing build and QA path are arm64.
- Universal Binary adds packaging and QA scope.
- Intel support is Phase 3.

### 2026-07-18: Defer Windows

Decision: Windows is out of scope for NotchMuse beta.

Reason:
- NotchMuse is a native macOS AppKit menu bar app.
- Windows would be a separate product architecture.

### 2026-07-18: Use project documents as status source

Decision: `PROJECT_STATUS.md`, `TASK_BOARD.md`, `DECISIONS.md`, and `ROADMAP.md` become the project status system.

Reason:
- Chat threads are useful for execution, but not reliable as the only project memory.
- Code remains the source of implementation truth.
- Project documents remain the source of management truth.

### 2026-07-22: Publish an unsigned GitHub Open Source Beta

Decision: Developer ID signing and notarization are not blockers for the
GitHub Open Source Beta when the unsigned-app installation path is documented.

Reason:
- The release target is GitHub Pre-release, not App Store distribution.
- The DMG, checksum, installation, and macOS security-warning path were
  verified.
- Signing and notarization remain future distribution work.

### 2026-07-24: Keep Phase 2 focused on Lyrics Quality

Decision: `v0.3.1`, `v0.4`, and `v0.5` prioritize Benchmark evidence,
matching safety, provider health, and confirmed beta issues.

Reason:
- Seven-day data shows failure categories change over time and require better
  attribution before production changes.
- Windows, Intel, Universal Binary, and new music platforms add scope without
  improving the current core lyrics experience.
- Platform expansion remains deferred until a future roadmap decision.

### 2026-07-24: Approve logging-only v0.3.1 code entry

Decision: The next code sprint may implement Matcher Decision Logging only.
Title normalization, Provider priority changes, and LRCLIB App retry remain
out of scope.

Reason:
- `128/216` audited title mismatches are provider response or classification
  drift, and rejected candidate metadata is missing.
- LRCLIB's immediate second retry recovered `0/25` replay failures.
- App providers already run concurrently, so Benchmark ranking is not an App
  priority strategy.
- DEBUG-only decision logs are the smallest change that closes the evidence
  gap without altering matching results.
