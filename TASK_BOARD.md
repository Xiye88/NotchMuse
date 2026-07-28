# NotchMuse Task Board

Last Updated: 2026-07-28

## TODO

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Align 50-100 failed tracks with DEBUG evidence | 03_LAB / 05_MATCHER | P0 | Candidate, score, reject reason, final decision |
| Classify LRCMux HTTP 404 semantics | 03_LAB | P1 | Do not retry until classified |
| Investigate NetEase response/parser failure | 03_LAB | P1 | Keep separate from matcher |
| Stratified LRCLIB retry experiment | 03_LAB | P2 | Benchmark only |
| Replace Demo links with GitHub native attachments | 06_DOCS | P2 | Requires browser local-file access |
| Re-capture Status Bar screenshot | 06_DOCS / 04_UX | P2 | Current left lyric edge is cropped |
| Complete real clean-Mac user journey | 04_UX | P0 | Gatekeeper, TCC, Spotify, lyrics recovery |
| Run first weekly beta issue triage | 00_PM / 06_DOCS | P1 | After targeted promotion |

## IN PROGRESS

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Structured beta feedback intake | 06_DOCS / 00_PM | P1 | Templates ready; collect issues |
| v0.4 Evidence Gate | 03_LAB / 05_MATCHER | P0 | Candidate evidence before matcher changes |
| Provider Health Classification | 03_LAB | P0 | NetEase, LRCMux 404, LRCLIB transient |
| Controlled early-beta promotion | 00_PM / 06_DOCS | P1 | Use prepared honest beta copy |
| Failure taxonomy split | 03_LAB | P0 | Separate no-result, unavailable, parser, transient |

## BLOCKED

| Task | Owner | Priority | Blocker |
| --- | --- | --- | --- |
| Title normalization implementation | 05_MATCHER | P1 | Rejected candidate evidence missing |
| LRCLIB App retry | 01_APP / 03_LAB | P1 | Second retry success `0/25` |
| Universal Binary and new platforms | 01_APP / 04_UX | P2 | Deferred by Phase 2 scope |
| Broad public promotion | 00_PM / 06_DOCS | P1 | Clean-user journey and first issue triage missing |

## DONE

| Task | Owner | Priority | Result |
| --- | --- | --- | --- |
| GitHub `v0.3.0-beta` release | Project | P0 | Published and verified |
| GitHub `v0.3.1` release | Project | P0 | Pre-release published; downloaded DMG verified |
| Freeze v0.3.1 repository diff | 00_PM / 01_APP | P0 | Release commit `3666710` |
| Rebuild v0.3.1 DMG | 01_APP / 02_RELEASE | P0 | SHA-256 `f8b0efe3...fcedb0` |
| Push v0.3.1 tag and Release | 02_RELEASE / 00_PM | P0 | DMG and checksum uploaded |
| Restore VPS access | 03_LAB | P0 | Existing SSH key works |
| Verify 7-day Benchmark baseline | 03_LAB | P0 | Average Coverage `66.09%` |
| Verify Daily Benchmark Pipeline | 03_LAB | P0 | Timer enabled/active; 7 runs healthy |
| Network failure evidence audit | 03_LAB / 05_MATCHER | P1 | Generic retry rejected |
| Matcher upgrade design | 05_MATCHER | P1 | Safe batches and gates defined |
| GitHub maintenance templates | 06_DOCS | P1 | Bug and feature templates added |
| Title mismatch audit | 05_MATCHER | P1 | Drift is `128/216` |
| Provider health audit | 03_LAB | P1 | LRCMux leads; NetEase unhealthy |
| LRCLIB retry experiment | 03_LAB | P1 | App retry No-Go |
| Matcher observability design | 05_MATCHER | P1 | Minimal DEBUG design ready |
| Implementation readiness review | 01_APP | P0 | Logging-only Go |
| Matcher Decision Logging implementation | 01_APP / 05_MATCHER | P0 | DEBUG-only; matching behavior unchanged |
| DEBUG vs Release logging validation | 01_APP | P0 | Self-tests, Release build, boundary scan PASS |
| NetEase provider priority recommendation | 03_LAB | P1 | Keep unchanged pending controlled decision |
| Lyrics Marquee behavior fix | 01_APP / 04_UX | P1 | 1.2s delay, forward-only, endpoint stop |
| Lyrics Animation automated QA | 04_UX | P1 | Automated and static checks PASS |
| Real-device UX Smoke Test | 04_UX | P0 | PASS with transient Notch known risk |
| Hide Lyrics / Show Lyrics fix | 01_APP / 04_UX | P0 | Both modes hide and restore current state |
| Notch / Overlay click-through fix | 01_APP / 04_UX | P0 | Real Spotify target received click |
| Critical UX smoke test | 04_UX / 00_PM | P0 | PASS; final RC Freeze GO |
| GitHub Demo video package | 06_DOCS | P1 | Two MP4 demos and README presentation update complete |
| Release Candidate regression | 01_APP | P0 | Build, tests, launch, logging boundary PASS |
| Benchmark next-step review | 03_LAB | P1 | Minimum Failure Analysis Pipeline defined |
| Matcher Release boundary review | 05_MATCHER | P0 | PASS; no production behavior change |
| Local v0.3.1 RC artifact | 01_APP | P0 | Build 4 DMG verified |
| Phase 2 Benchmark health check | 03_LAB | P1 | Latest `68.9%`; 7-run average `67.16%` |
| v0.4 Matcher roadmap | 05_MATCHER | P1 | Evidence Gate first; false positives must remain `0` |
| Public Beta feedback guide | 06_DOCS | P1 | `FEEDBACK.md` linked from README |
| GitHub growth audit | 06_DOCS | P1 | Presentation and issue intake PASS |
| Localization final review | 01_APP / 04_UX | P1 | English default; manual Chinese selection PASS |
| Platform expansion decision | 01_APP | P2 | Apple Music first future candidate; implementation deferred |
| Beta promotion package | 00_PM / 06_DOCS | P1 | X, Reddit, and GitHub early-beta drafts ready |
| Beta User Journey final audit | 04_UX | P0 | PASS WITH RISKS; clean Mac still required |
| 60-case Failure Taxonomy sample | 03_LAB | P0 | 15 samples in each requested class |
| v0.4 Provider Health analysis | 03_LAB | P0 | LRCMux/LRCLIB/NetEase root boundaries set |
| Matcher Evidence readiness | 05_MATCHER | P0 | GO without code changes |
| Beta Support Package | 06_DOCS | P1 | `SUPPORT.md` and README links ready |
| v0.5 priority review | 01_APP | P1 | Apple Music first conditional candidate |
| Bilingual GitHub README | 06_DOCS | P1 | Full Simplified Chinese README and language switch |
| Bilingual Quick Start | 06_DOCS / 04_UX | P1 | Requirements, install, permission, menu bar entry |
| Latest VPS evidence check | 03_LAB | P0 | Runs 15-16 healthy; latest Coverage `68.4%` |
| Next Matcher Evidence Gate | 05_MATCHER | P0 | Normalization NO-GO; candidate alignment defined |
| Rejected candidate evidence capture | 03_LAB / 05_MATCHER | P0 | Verified locally and deployed to VPS |
| Bilingual Release usage links | 06_DOCS | P1 | English, Chinese, Support, and menu bar entry |
| Matcher evidence reporting | 03_LAB / 05_MATCHER | P0 | Structured JSON and Markdown aggregation verified |
