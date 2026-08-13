# NotchMuse Task Board

Last Updated: 2026-08-14

## TODO

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Manually label run 19 proposed recoveries | 03_LAB / 05_MATCHER | P0 | 464 eligible provider rows; false positives must remain 0 |
| Classify LRCMux HTTP 404 semantics | 03_LAB | P1 | Do not retry until classified |
| Build fixed 100-song popular-miss Provider matrix | 03_LAB | P1 | Report unique incremental Coverage and verified sync correctness |
| Package validated Provider recovery into a public hotfix | 01_APP / 02_RELEASE | P0 | Current `v0.3.1` DMG predates commit `8c205e3` |
| Audit Soda invalid-response regression | 03_LAB | P0 | Run 28: `0/1000`, all JSON parse failures; no Matcher changes |
| Label a fixed sample from 108 remaining misses | 03_LAB / 05_MATCHER | P0 | Prioritize Korean, Chinese pop, Spotify hot, and Japanese tracks |
| Stratified LRCLIB retry experiment | 03_LAB | P2 | Benchmark only |
| Replace Demo links with GitHub native attachments | 06_DOCS | P2 | Requires browser local-file access |
| Re-capture Status Bar screenshot | 06_DOCS / 04_UX | P2 | Current left lyric edge is cropped |
| Complete real clean-Mac user journey | 04_UX | P0 | Gatekeeper, TCC, Spotify, lyrics recovery |
| Run first weekly beta issue triage | 00_PM / 06_DOCS | P1 | Blocked by zero submitted Issues and very low download volume |
| Apple Music five-song runtime matrix | 01_APP / 04_UX | P0 | Partial real pass; needs five screenshot-backed complete-chain cases after Music.app playback is restored |
| Label v0.6 frozen ranking cases | 03_LAB / 05_MATCHER | P1 | Strategy-blind labels; every changed decision reviewed |
| QQ Music current-version field probe | 01_APP | P2 | Requires a Mac with QQ Music installed; private probe only |
| NetEase current-version field probe | 01_APP | P2 | Stop if timing fields are unstable; no AX production path |

## IN PROGRESS

| Task | Owner | Priority | Notes |
| --- | --- | --- | --- |
| Structured beta feedback intake | 06_DOCS / 00_PM | P1 | Templates ready; collect issues |
| v0.5 Phase 4 labeled simulation | 03_LAB / 05_MATCHER | P0 | Run 19 identity gate passed; manual ground truth pending |
| Remaining Provider Health Classification | 03_LAB | P0 | Soda invalid response and LRCMux 404 semantics |
| Controlled early-beta promotion | 00_PM / 06_DOCS | P1 | Use prepared honest beta copy |
| Phase 4 Matcher Go/No-Go | 00_PM / 03_LAB / 05_MATCHER | P0 | Simulator ready; production remains unchanged |
| v0.6 Apple Music production integration | 01_APP / 04_UX | P0 | Shared pipeline and partial real playback pass; permission denial and full five-song matrix pending |
| v0.6 player regression validation | 01_APP / 04_UX | P0 | Music.app clears current track after restart; Spotify authenticated but content playback unavailable |

## BLOCKED

| Task | Owner | Priority | Blocker |
| --- | --- | --- | --- |
| Title normalization implementation | 05_MATCHER | P1 | Phase 3 second-candidate evidence takes priority; no safe normalization rule |
| Production Matcher implementation | 01_APP / 05_MATCHER | P0 | No strategy has passed labeled accuracy and zero-false-positive gate |
| Production Provider expansion | 01_APP / 03_LAB | P0 | Existing Provider health and Benchmark/App parity unresolved |
| Artist normalization implementation | 05_MATCHER | P1 | Second-candidate identity is required before ranking conclusions |
| Track Identity album / mandatory ISRC | 05_MATCHER / 01_APP | P1 | Candidate fields incomplete; no safe evidence yet |
| LRCLIB App retry | 01_APP / 03_LAB | P1 | Second retry success `0/25` |
| Universal Binary and new platforms | 01_APP / 04_UX | P2 | Deferred by Phase 2 scope |
| Broad public promotion | 00_PM / 06_DOCS | P1 | Clean-user journey and first issue triage missing |
| Retention-driven roadmap decisions | 00_PM | P1 | No Issues and only three DMG downloads; insufficient user evidence |
| Apple Music Release integration | 01_APP / 04_UX | P0 | Five-song Apple Music matrix and authenticated Spotify parity not complete |
| QQ Music production integration | 01_APP | P2 | No stable public now-playing API verified |
| NetEase player production integration | 01_APP | P2 | No stable public now-playing API verified |
| Track Identity enhanced ranking | 03_LAB / 05_MATCHER | P1 | Dataset frozen; human labels 0/2,568 and candidate album/ISRC absent |

## DONE

| Task | Owner | Priority | Result |
| --- | --- | --- | --- |
| Apple Music production routing | 01_APP / 04_UX | P0 | Settings selection feeds shared Adapter, LyricsClient, Status Bar and Notch path; automated verification PASS |
| Spotify Adapter implementation | 01_APP | P0 | Minimal wrapper wired; SpotifyReader and lyrics boundary preserved; self-tests pass |
| Apple Music public API spike code | 01_APP / 04_UX | P0 | State read and parser pass; runtime remains Conditional Go |
| Track Identity v1 representation | 01_APP / 05_MATCHER | P1 | Neutral metadata and version hints added; production Matcher unchanged |
| Feedback Email finalization | 01_APP / 04_UX | P1 | READY; single build config, bilingual drafts, no-song, both sources, Cancel and Send verified |
| Track Identity Dataset v1 freeze | 03_LAB / 05_MATCHER | P1 | Run 32; 2,568 cases; SHA-256 b0bbb940...; Apple Music catalog proxy labeled |
| Batch 2 Candidate Ranking gate | 03_LAB / 05_MATCHER | P1 | Production NO-GO; 0 human labels means requested deltas are not computable |
| QQ / NetEase diagnostic probe | 01_APP | P2 | Both production No-Go; no public scripting interface verified |
| LyricsX UX bounded backlog | 04_UX | P2 | Three near-term recommendations; no UI redesign |
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
| Matcher evidence reporting | 03_LAB / 05_MATCHER | P0 | Verified on natural runs 17-18 |
| v0.5 Phase 1 Failure Analysis | 03_LAB | P0 | Runs 17-18 verified; 80-song dataset created |
| v0.5 Phase 2 Matcher Improvement Proposal | 05_MATCHER | P0 | Production NO-GO; second-candidate evidence extension approved |
| Lyrics Failure UX Audit | 04_UX | P1 | No P0; three P1 copy risks identified |
| Production Stability Boundary Review | 01_APP | P0 | Benchmark isolated; Release DEBUG logging remains off |
| Second-candidate evidence extension | 03_LAB / 05_MATCHER | P0 | Commit `08acf82`; deployed and remote tests passed |
| Offline ranking simulator | 05_MATCHER | P0 | Benchmark-only; four signal groups; 23 tests pass |
| Top Songs proxy dataset | 03_LAB | P1 | 300 unique tracks; run 18 weighted baseline `72.9%` |
| Failure-state copy review | 04_UX | P1 | Proposal complete; no Swift or behavior change |
| Natural run 19 evidence verification | 03_LAB | P0 | 489/489 second identity filled; snapshot hash matched VPS |
| Phase 3 de-duplication Go/No-Go | 05_MATCHER | P0 | Benchmark-only GO for 464 equivalent rows; production NO-GO |
| Phase 4 run 19 simulation audit | 03_LAB / 05_MATCHER | P0 | 101-song recovery upper bound; no labeled accuracy claim |
| Open-source lyrics source landscape | 00_PM / 03_LAB | P0 | Existing-source recovery first; Musixmatch official is conditional |
| Existing Provider recovery implementation | 01_APP / 03_LAB / 05_MATCHER | P0 | LRCLIB, NetEase, and Kugou repaired without Matcher changes |
| Top Songs missing-track replay | 03_LAB / 05_MATCHER | P0 | Recovered 6/9; bounded first-100 result 91 to potential 97 |
| Provider recovery natural validation | 03_LAB / 05_MATCHER | P0 | Runs 21-28 average `89.38%`; latest `89.2%` |
| Latest Top Songs natural validation | 03_LAB | P0 | Run 28: `277/300` overall and `96/100` first 100 |
| 2026-08-09 code verification | 01_APP / 03_LAB | P0 | Swift self-tests, Release build, and 26 Python tests passed |
| LyricsX / LyricFever deep source audit | 01_APP / 04_UX / 05_MATCHER | P0 | Player, lyrics and floating UX boundaries documented |
| Unified Music Player Layer design | 01_APP / 05_MATCHER | P0 | Progressive Spotify-first migration approved for spike |
| Apple Music feasibility review | 01_APP | P0 | Public Apple Events path verified; runtime spike pending |
| QQ / NetEase player feasibility review | 01_APP | P1 | Diagnostic probes only; production paths rejected |
| v0.6 Track Identity experiment design | 03_LAB / 05_MATCHER | P1 | Benchmark-only gate; production Matcher unchanged |
| Email feedback UX design | 01_APP / 04_UX | P1 | Native mailto flow became the READY Batch 2 implementation |
