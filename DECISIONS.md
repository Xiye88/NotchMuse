# NotchMuse Decisions

Last Updated: 2026-07-18

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
