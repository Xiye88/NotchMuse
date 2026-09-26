# NotchMuse Task Board

## Active Integration — QQ Music/Soda Music + Accepted Settings UI

- Status: DONE / Product Owner accepted v2 preview images.
- Branch: `codex/settings-visual-polish`, based on main `484039f`.
- Scope: Settings sidebar, preview, cards, spacing, and appearance preset tiles.
  No player, NetEase, Matcher, or Provider changes.
- Main UI source: `a5f1938`; build 24 deployment and CI `36223310974` passed.
- Combined source: main `22fb8e8`; build 28 App/DMG verified.
- CI `36228752066` PASS; build 28 installed with matching executable and Preview resource.
- Pending: user acceptance of unified installed candidate. No public release authorized.
### Prior Isolated Integration Evidence
- Workspace: PM integration on `codex/player-expansion-integration`.
- Settings Visual Polish v2 was accepted by Product Owner and integrated into
  main at `a5f193832dd7889a3ebf25d1087dae867ff68813`; CI `36223310974` passed.
- This isolated branch integrates that main state with QQ/Soda support and the
  playback-clock fix. No Settings UI edits are made on this branch.
- Baseline before player expansion: `776437a352d8f81ce6915c4779766f91d3142047`.
- Player implementation commit `d933c62` and timing fix `63c2ec0`; timing-fix
  CI `36226306542` passed. Local candidate build 26 is installed in
  `/Applications` from the earlier phase; this integration task must not replace
  it. The isolated artifact and hash are recorded in `PROJECT_HANDOFF.md`.
- Product Owner GUI feedback: QQ and Soda lyrics match correctly; check the
  timing fix alongside the integrated Settings v2 through a temporary isolated
  app launch.
- Remaining gate: short Settings smoke and timing confirmation on the isolated
  candidate. Do not merge main or generate final `PLAYER_EXPANSION_HANDOFF.md`.
- Local `swift test` cannot load XCTest with the active Command Line Tools.
- No merge to main, tag, or publication is authorized in this integration.
- Evidence: interim `PLAYER_EXPANSION_HANDOFF.md`.

## Completed Next Task

- `10_SETTINGS_UI` — **DONE / ARCHIVED**.
- Blocked by: stable `09_REPO_ARCHITECTURE` source layout.
- Dependency gate was satisfied. Implementation started from stable main
  `101e550af4814b34d25b9b8e5f32af3252bb0606` in an isolated worktree and
  was integrated into main as `279b910`.
- Design handoff: `docs/project/NotchMuse_Settings_UI_Redesign_PM_Handoff.md`.
- Result: Debug/full self-test, English/Simplified Chinese GUI smoke, branch CI,
  Release build, ad-hoc signature, and DMG verification passed. Public release
  remains a separate Product Owner decision.
- Main deployment closure: old `/Applications/NotchMuse.app` build 18 was
  replaced with build 21 from main `776437a`; installed executable checksum
  matches the Release package. NetEase short smoke passed; Product Owner
  confirmed installed Settings sidebar, Live Preview, cards, and presets: PASS.

## Repository Architecture Cleanup — First Round (2026-09-25)

- Workspace: `09_REPO_ARCHITECTURE` — DONE / ARCHIVED on
  `codex/repository-architecture-cleanup`.
- Start SHA verified: `3fb6946602dd35308d201fe7d5e609e63ebcb42e`; completion
  SHA is the branch tip after this report commit.
- Reviewed audit/CI commit `403feb5` cherry-picked as `19da5a8`.
- Complete locally: CI baseline checks, Debug full self-test, Release packaged
  resource smoke test, Swift package tests in CI, Release app/DMG build,
  signature and checksum verification, bilingual docs, and report archive.
- CI runs through `36153359262` are green on macos-15, including `swift test`;
  the earlier macos-14 run failed because it defaulted to Swift 5.10.
- Local CLT still lacks XCTest, but CI covers formal tests. Runtime/player
  behavior stays frozen.
- Source moves are complete; `AppLocalization.swift` stays at root because it
  locates localized resources relative to `#filePath`.
- Completion report: `reports/github/09-repository-architecture-cleanup.md`.
- Final SHA: `0495971a2ce948289320226cfb67656987352756`; final CI run
  `36157250718` passed. Handoff to `00_PM` is complete.
- Final documentation head `d5673b9b5b9e25baff4abb57db2264f30ace19c2`
  was integrated into `main` by merge commit
  `7bc74acd9abe8f6c4b5eb185b3dd5dd51c273ff0`.

Last Updated: 2026-09-26

## Sprint

v0.8 Main Closure: DONE. Build 21 is installed locally and its Settings GUI
check passed. Public release remains a separate approval.

## Workspace Registry

Workspace numbers are unique. A completed workspace moves to `DONE`, then to
`ARCHIVED` when its result has been merged or handed off.

| Workspace | Status | Current responsibility |
| --- | --- | --- |
| `00_PM` | ACTIVE | Sprint coordination, integration, gates, and release decision |
| `01_APP` | ARCHIVED | P0 merged as `28d7a3b`; branch retained |
| `02_RELEASE` | ARCHIVED | No release work during Stability Fix Sprint |
| `03_LAB` | ARCHIVED | Benchmark experiments; reopen only with a new evidence question |
| `04_UX` | ARCHIVED | P1 merged as `46dc4f5`; branch retained |
| `05_MATCHER` | ARCHIVED | v0.7 evidence gate was NO-GO; Production Matcher remains frozen |
| `06_DOCS` | ARCHIVED | `00_PM` updates Handoff after each development phase |
| `07_QA` | ARCHIVED | Focused QA phases merged through `7423dcc`; report retained |

## Sprint Work

| ID | Priority | Owner | Status | Deliverable / exit criteria |
| --- | --- | --- | --- | --- |
| `P0.1` | P0 | `00_PM` | DONE | Only `/Applications/NotchMuse.app` build 18 is the installed candidate; executable hash, one launch entry, helper pair, preferences, and Auto Detect are verified |
| `P0-1` | P0 | `01_APP` | DONE | Auto/Spotify/Apple Music/NetEase Settings options and restart persistence have regression coverage |
| `P0-2` | P0 | `01_APP` | DONE | Auto selection uses playback state and freshness, preserves deterministic ownership, and does not select merely because an app is open |
| `P0-3` | P0 | `01_APP` | DONE | NetEase rejects stale asynchronous state, reused track identifiers, and expired provider data; build 18 real-player regression PASS |
| `P1-1` | P1 | `04_UX` | DONE | Background/hover/stopped behavior, arbitrary lyric color with presets, numeric inputs, and functional Custom Width are implemented |
| `QA-GATE` | P1 | `07_QA` | DONE — FINAL RC | Build 18 runtime gates remain PASS; build 20 adds the verified Settings-only redesign and passes full self-test, bilingual GUI smoke, signing, and DMG verification. |

## Current Evidence

### 2026-09-25 Final Closure — GO

- Verified startup HEAD and `codex/netease-production-candidate` at
  `dee834f533812aac3e1dcab83f5d62a008d6a906` after `git fetch`.
- Installed candidate is `0.8.0` build `18`, arm64, ad-hoc signed (no Team ID);
  executable SHA-256:
  `4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`.
- NetEase seek root cause is the two-second adapter position refresh interval
  combined with the one-second app poll. A one-second refresh adjustment now
  passes self-tests for large-position lyric resync, stable track identity,
  and no repeat lyric request. Product Owner confirms seek forward/back passed. Final consolidated GUI confirmation
  is PASS for Notch/current/restart lyrics, custom color persistence, Hide on Hover,
  Auto Detect matrix/owner/fallback/stale clearing, Sleep/Wake, and network recovery.
  No step-level details or durations were supplied.
- Debug/Release build and self-tests, codesign deep verification, DMG verification,
  exact 102/102 English/Chinese key parity, and `git diff --check`: PASS. Valid
  Build 18 continuous-playback soak ran 20:46:21–21:46:24 CST; 15/30/60-minute
  samples passed with one app/watchdog/Perl each and no crash, restart, or helper
  orphan. Full evidence: `/tmp/notchmuse-build18-soak.log`. Lyrics/stale GUI checks
  are covered by the Product Owner final GUI PASS. The 20:40 paused pre-sample is invalid and retained separately. Candidate decision: GO — FROZEN / READY FOR
  RELEASE REVIEW; this is not authorization to publish.

### Historical Git Sync Snapshot (candidate backup)

- Branch: `codex/netease-production-candidate`
- Commit SHA: `4877b6126f0889d65db65f5b08995be2db90021b`
- Remote: `origin` (`https://github.com/Xiye88/NotchMuse.git`)
- Push result: SUCCESS; `origin/codex/netease-production-candidate` created and
  upstream configured.
- `origin/main`: `8a45e2254929ee97910ba94d1e698e44d5e2205f`;
  candidate ahead 35, behind 0 at backup time.
- Main/tag/Release mutation: NONE.
- Local-only follow-up: dirty experimental root and standalone visible-lyrics
  validator remain preserved and require separate triage; no Candidate runtime
  code is missing from the pushed development branch.

- Stability integration commits: `28d7a3b` (App) and `46dc4f5` (UX) on
  `codex/netease-production-candidate`.
- Release and Debug builds plus self-tests: PASS.
- Local build `15` DMG SHA-256:
  `215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
- `codesign --verify --deep --strict` and `hdiutil verify`: PASS.
- Signing: ad-hoc, arm64, no Team ID; Gatekeeper assessment: rejected.
- Development branch push: COMPLETE. Main merge, tag, and GitHub Release: NOT
  STARTED.
- Installed app: one `/Applications/NotchMuse.app`, version `0.8.0` build `15`;
  Spotlight returns one result and Player Source is Auto Detect.
- Focused Auto Detect runtime: Spotify and Apple Music were closed, NetEase
  was the only running player, MediaRemote owner was `com.netease.163music`
  with `playing=true`, and NotchMuse visibly rendered its current lyric.
- Focused QA report: `reports/2026-09-23-v08-stability-focused-qa.md`.

## Physical Worktrees

- PM/integration: `.worktrees/netease-production-candidate` (clean/current).
- QA worktree was removed after its report merged; branch/history remain.
- APP and UX worktrees were cleanly removed after merge; their branches and
  commit history remain.
- Legacy experiment root: repository root (dirty; retained until its uncommitted
  evidence is migrated or archived).
- Four clean duplicate worktrees were deregistered; their branches and Git
  history remain intact.

## Product Decisions and Current Freeze

- Player selection options: Auto Detect (recommended), Spotify, Apple Music,
  and NetEase Cloud Music.
- When the player exits, the default is to hide lyrics and wait for recovery.
  The alternative keeps the final lyric visible and paused.
- Production Matcher, thresholds, ranking, and Provider priority remain frozen.
- v0.8 build 18 is FROZEN / READY FOR RELEASE REVIEW. Public release still
  requires its separate Product Owner approval.

## Future — Not In This Sprint

Plan `notchmuse.com` after v0.8. The public download surface will contain only
the DMG, checksum, `latest.json`, landing page, and release notes. Source code
will not be uploaded to the website. No website implementation is authorized
in this sprint.

## Archived Evidence

- v0.6.0 and v0.6.1 were published with Spotify and Apple Music support.
- v0.7 and v0.7.1 Matcher/metadata gates ended NO-GO.
- The prior NetEase candidate reached build 14 and produced a locally verified
  DMG, but it was not merged, pushed, tagged, or released.
