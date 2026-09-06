# NetEase Production Candidate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle the pinned MediaRemote bridge and integrate NetEase Cloud Music as a safely gated third NotchMuse player.

**Architecture:** Package the pinned framework, Perl script, and helper inside the app. A dedicated `MediaRemoteBridge` owns process I/O and recovery; `NetEaseMusicAdapter` converts converged NetEase events into the existing `MusicPlayerSnapshot` contract.

**Tech Stack:** Swift 6, AppKit, Foundation `Process`, Swift Package Manager, shell app-bundle scripts, CMake-built universal framework.

**Spec:** `docs/superpowers/specs/2026-09-06-netease-production-candidate-design.md`

## Global Constraints

- Do not modify Production Matcher or Provider priority.
- Do not change SpotifyReader or AppleMusicAdapter behavior.
- Users must not need Homebrew, media-control, CMake, or terminal setup.
- Production paths resolve only from `Bundle.main.resourceURL`.
- Dependency commit is `6bbb7d30f9ddb209a583fa509b9ca145df97f502`.
- Do not publish v0.8 before the Production Gate.

---

### Task 1: Vendor And Compliance

**Files:**
- Create: `MenuBarLyrics/Vendor/MediaRemoteBridge/*`
- Create: `scripts/build_mediaremote_bridge.sh`
- Modify: `THIRD_PARTY_NOTICES.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Interfaces:**
- Produces the fixed `MediaRemoteBridge` resource directory consumed by Task 2 and the app build.

- [ ] Copy the verified framework, helper, Perl script, BSD license, and a `VERSION.json` containing repository, commit, and artifact SHA-256 values.
- [ ] Add a maintainer-only rebuild script that clones the exact commit, runs CMake, and replaces only the vendored artifacts.
- [ ] Record BSD-3-Clause attribution in `THIRD_PARTY_NOTICES.md`; add one short acknowledgement to both READMEs.
- [ ] Verify framework/helper architectures, script syntax, helper execute permission, hashes, and license presence.

### Task 2: Production MediaRemoteBridge

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/MediaRemoteBridge.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Produces `MediaRemoteBridge.bundled() throws`, `healthCheck(timeout:)`, `get(timeout:)`, `startStream(onEvent:onFailure:)`, and `shutdown()`.
- Emits decoded full `MediaRemoteEvent` values from `{type,diff,payload}` stream envelopes.

- [ ] Add failing SelfTests for Bundle-relative layout, string/numeric identifiers, empty payloads, malformed JSON, timeout, duplicate stream start, and shutdown.
- [ ] Run SelfTests and confirm the new assertions fail before implementation.
- [ ] Move only validated experiment logic into Production, add bounded process timeout and one-stream ownership, then remove all absolute test paths.
- [ ] Run SelfTests and Swift 6 build until clean.

### Task 3: Evidence-based Event Convergence

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/NetEaseEventConverger.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- Consumes `MediaRemoteEvent`.
- Produces committed NetEase events after duplicate filtering and a 300 ms convergence window.

- [ ] Add failing tests for exact duplicates, immediate same-track playback changes, two matching new identities, 300 ms quiet commit, foreign-owner clearing, and rapid A/B/C transitions.
- [ ] Implement the smallest deterministic state machine matching the design rules.
- [ ] Verify no test relies on fuzzy title, score, threshold, or Provider behavior.

### Task 4: NetEase Player Adapter And Selection

**Files:**
- Create: `MenuBarLyrics/Sources/MenuBarLyrics/NetEaseMusicAdapter.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MusicPlayerAdapter.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/MenuBarController.swift`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SettingsWindowController.swift`
- Modify: `MenuBarLyrics/Resources/en.lproj/Localizable.strings`
- Modify: `MenuBarLyrics/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `MenuBarLyrics/Sources/MenuBarLyrics/SelfTests.swift`

**Interfaces:**
- `PlayerSource.netEaseMusic` maps to `NetEaseMusicAdapter`.
- `MusicPlayerAdapter.shutdown()` defaults to no-op; NetEase terminates Bridge resources.

- [ ] Add failing tests for preference persistence, localized name, NetEase event mapping, foreign owner rejection, closed/stopped/unavailable states, and explicit shutdown.
- [ ] Add the third source without changing the default `.spotify` or automatic source selection.
- [ ] Call `shutdown()` before replacing an Adapter and from `MenuBarController.stop()`.
- [ ] Use source-specific unavailable guidance rather than Apple Music Automation text.
- [ ] Run all SelfTests.

### Task 5: App Bundle Packaging

**Files:**
- Modify: `scripts/build_app.sh`
- Modify: `scripts/build_release.sh`

**Interfaces:**
- Copies vendor input to `Contents/Resources/MediaRemoteBridge` and signs nested executable content before the app.

- [ ] Add pre-copy hash and version validation.
- [ ] Copy resources, restore execute permissions, sign framework/helper, then sign NotchMuse.
- [ ] Assert Bundle files, permissions, architectures, codesign, and Perl script syntax.
- [ ] Build an app, move it to `/Applications`, and run Bundle-path health/get smoke without source-tree paths.

### Task 6: UI And Event Runtime Gate

**Files:**
- Create: `reports/v0.8-netease-ui-runtime-report.md`
- Create: `reports/v0.8-netease-event-convergence-report.md`

- [ ] Test 20 real songs across Chinese, English, complex metadata, long/short/no lyrics in Status Bar and Notch Mode.
- [ ] Record final-title latency, lyric requests per switch, stale/flash behavior, marquee, next line, and mode switches.
- [ ] Verify transition snapshots produce one final track change and no duplicate LyricsClient request.

### Task 7: Lifecycle, Recovery, And Regression Gate

**Files:**
- Create: `reports/v0.8-netease-lifecycle-report.md`
- Create: `reports/v0.8-player-regression-report.md`

- [ ] Run 60 minutes with 30 switches, 10 pause/resume, three NetEase restarts, three NotchMuse restarts, two display modes, and two languages.
- [ ] Test missing player, no track, health failure, killed helper, broken stream, network loss/recovery, and Sleep/Wake.
- [ ] Alternate Spotify/NetEase/Apple Music at least 20 times and verify selected source, lyrics, and owner never cross.
- [ ] Run Spotify and Apple Music lyrics/switch/pause/restart/display regression.
- [ ] Record CPU, memory, FD count, Perl/helper count, and verify zero orphan after quit/crash.

### Task 8: Production Gate And Conditional Release

**Files:**
- Create: `reports/v0.8-production-gate-report.md`
- Modify: `PROJECT_STATUS.md`
- Modify: `TASK_BOARD.md`
- Modify: `ROADMAP.md`
- Modify only after GO/allowed CONDITIONAL GO: `CHANGELOG.md`, `README.md`, `README.zh-CN.md`, release notes.

- [ ] Classify every runtime finding as P0/P1/P2 and decide GO, CONDITIONAL GO, or NO-GO from the spec criteria.
- [ ] If Gate is NO-GO, stop without Release artifacts or GitHub changes.
- [ ] If Gate permits release, run clean audit, SelfTests, Release build, DMG, SHA-256, `hdiutil verify`, and installed-app smoke.
- [ ] Only after local artifact validation, push main, tag `v0.8.0`, create GitHub Pre-release, upload files, download them again, and verify all three players.
