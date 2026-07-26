# NotchMuse Task Board

Last Updated: 2026-07-26

## TODO

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Freeze v0.3.1 repository diff | 00_PM / 01_APP | P0 | Include validated P0 UX fixes |
| Prepare v0.3.1 release commit and tag | 00_PM / 01_APP | P0 | After safety audit |
| Rebuild DMG from release commit | 01_APP | P0 | Previous artifact superseded; verify new checksum |
| Collect rejected candidate samples | 03_LAB / 05_MATCHER | P1 | After logging exists |
| Classify LRCMux HTTP 404 semantics | 03_LAB | P1 | Do not retry until classified |
| Stratified LRCLIB retry experiment | 03_LAB | P2 | Benchmark only |
| Replace Demo links with GitHub native attachments | 06_DOCS | P2 | Requires browser local-file access |

## IN PROGRESS

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Structured beta feedback intake | 06_DOCS / 00_PM | P1 | Templates ready; collect issues |
| v0.3.1 Release Candidate freeze | 00_PM / 01_APP | P0 | Critical UX validation PASS; Git freeze pending |

## BLOCKED

| Task | Owner | Priority | Blocker |
| --- | --- | --- | --- |
| Title normalization implementation | 05_MATCHER | P1 | Rejected candidate evidence missing |
| LRCLIB App retry | 01_APP / 03_LAB | P1 | Second retry success `0/25` |
| Universal Binary and new platforms | 01_APP / 04_UX | P2 | Deferred by Phase 2 scope |

## DONE

| Task | Owner | Priority | Result |
| --- | --- | --- | --- |
| GitHub `v0.3.0-beta` release | Project | P0 | Published and verified |
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
