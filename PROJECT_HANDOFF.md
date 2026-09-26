# NotchMuse Project Handoff

## Player Expansion — Active Integration (2026-09-26)

- Latest main `a5f193832dd7889a3ebf25d1087dae867ff68813` contains the
  Product-Owner-accepted Settings Visual Polish v2; main CI `36223310974` passed.
- This isolated branch combines that main state with QQ/Soda support and timing
  fix `63c2ec0`; no Settings UI, Matcher, or Provider Priority edits were made
  during this integration. The merge commit is local only; it has not been pushed.
- Candidate `0.8.0` build `27` was built from the integrated working tree and
  remains in `dist.noindex/NotchMuse.app`. Executable SHA-256
  `b91b167c0860af7099acaec7f92d8b7cc63ccd5aeb1d70a27f244c012ce7f0f3`;
  bundled `SettingsPreviewWallpaper.png` SHA-256
  `e29bfda3092aacf38774e21ad4cb4c060dee555eed13e83fb0db368ebaade9d2`.
  `/Applications/NotchMuse.app` was not modified.
- Debug build/full self-tests, packaged self-test, resource presence, and
  strict signature verification pass. `swift test` remains unavailable locally
  because the active Command Line Tools lack XCTest; CI for the integrated
  merge has not been run.
- A temporary QA copy launched without touching the installed app and passed
  its first-launch screen. The computer-use interface could not access the
  menu-bar-only Settings window afterward, so a visible GUI regression remains
  pending. QQ/Soda GUI feedback from the prior candidate confirmed correct
  matching; timing confirmation on the integrated candidate is pending.
- No push, main merge, tag, or publication. Keep the final
  `PLAYER_EXPANSION_HANDOFF.md` deferred until acceptance is complete.

## v0.8 Final Engineering Main Integration

- Architecture final SHA:
  `d5673b9b5b9e25baff4abb57db2264f30ace19c2`.
- Main integration merge:
  `7bc74acd9abe8f6c4b5eb185b3dd5dd51c273ff0`.
- Installed build source:
  `776437a352d8f81ce6915c4779766f91d3142047`; present on remote main.
- Architecture CI `36158185905`: PASS.
- Main CI `36217972870`: PASS.
- `09_REPO_ARCHITECTURE`: DONE / ARCHIVED.
- `10_SETTINGS_UI`: DONE / ARCHIVED; integrated into main as `279b910`.
- No v0.8 tag, GitHub Release, or website publication has been created.

## Installed Build Closure — 2026-09-26

- Root cause of the reported old Settings UI: `/Applications/NotchMuse.app`
  still contained build 18 even though the redesign was on remote main.
- Rebuilt main as `0.8.0` build 21. The installed executable SHA-256 is
  `cda3bcbf805519e7b9a51c7ecdd90fec76be1b5aa61d00221c483ad3aa51aa13`,
  identical to the new package. DMG SHA-256 is
  `ea1d037ec22ceb646627b2ecf78104e3ae029395767b6dadc94ef6718727e4b6`.
- Old build 18 remains recoverable at
  `/tmp/NotchMuse-build18-before-settings-20260926.app`.
- Installed NetEase short smoke: Auto Detect, Play, Pause/Resume,
  Next/Previous, seek, and visible lyrics checked. Product Owner separately
  reports approximately 7-8 hours of use as MANUAL PASS.
- Product Owner opened the installed build 21 Settings window and confirmed
  sidebar, Live Preview, card layout, and presets: GUI PASS. v0.8 main closure
  is DONE; no tag or GitHub Release was created.

## Completed Follow-up — 10_SETTINGS_UI

- Status: `DONE / ARCHIVED`.
- Blocked by: stable `09_REPO_ARCHITECTURE` source structure.
- Starting baseline: stable main
  `101e550af4814b34d25b9b8e5f32af3252bb0606`.
- Source handoff: `docs/project/NotchMuse_Settings_UI_Redesign_PM_Handoff.md`.
- Isolated branch head: `5d74ce67ad25dfd9fa1c0a036cc4f06d05772575`;
  CI run `36213755351` passed. English and Simplified Chinese GUI smoke verified
  the real Settings window, all three sections, live previews, presets, and
  localized Auto Detect. Main build `21` passed full self-test, ad-hoc signing,
  and DMG verification.
- The remaining Product Owner decision is whether to create the v0.8.0 tag and
  GitHub Release. Developer ID signing, notarization, and stapling remain
  intentionally deferred.

## Repository Architecture Cleanup — Final Handoff (2026-09-25)

- Status: Repository cleanup, CI workflow, tests, documentation, and build
  artifact standardization are complete on the architecture branch.
- Branch: `codex/repository-architecture-cleanup`; final SHA recorded after the
  completion commit. `origin/main` remains
  `8a45e2254929ee97910ba94d1e698e44d5e2205f`.
- Verified start SHA: `3fb6946602dd35308d201fe7d5e609e63ebcb42e`.
- Reviewed audit/CI commit `403feb55027b269f7b7ff967f50722bf5e93596a`
  cherry-picked as `19da5a8`; it contains the CI workflow, audit report, and
  Handoff audit section only.
- Latest result: CI runs `36151054620`, `36151541293`, `36151776806`,
  `36152073006`, `36152329273`, `36152688614`, and `36153359262` passed on
  `macos-15` (Swift 6), including Debug, `swift test`, Release/DMG, and packaged
  self-tests. Source files are grouped under App/Players/Lyrics/UI/Support;
  LyricsCore is a separate library/test target. The initial `macos-14` run
  failed before compilation on Swift 5.10; the workflow runner was corrected.
  Latest local build 19 and DMG verify with metadata/checksums; the final CI run
  must also pass on the completion commit.
- Architecture branch is pushed and integrated into `main` by merge commit
  `7bc74acd9abe8f6c4b5eb185b3dd5dd51c273ff0`. No tag, GitHub Release, or
  website publication has occurred.
- Scope: extract only `LyricParser` and `LyricClock` pure logic for the initial
  formal tests; preserve runtime behavior. Full app self-tests run in Debug;
  Release `--self-test` checks packaged localization and bridge resources. No player,
  matcher, UI, default-setting, or vendor-binary changes.
- Commits: `6c34617` added the focused lyrics core test target; `2dffbcd`
  switched CI to the Swift 6 runner; source batches are `1840179`, `914e96e`,
  `256943e`, `e9424ab`, `1c32ef0`, and `93c03b2`. CI is green. The macos-15
  image emits a non-blocking `actions/checkout@v4` Node.js 20 deprecation
  warning.
- Blocker: none for the authorized branch work. The local CLT limitation does
  not block formal test execution in CI.
- Note: `AppLocalization.swift` remains at the target root because its
  `#filePath` fallback resolves `Resources` from that location. Moving it
  without the matching path adjustment failed the localization self-test; the
  attempted move was reverted.
- Engineering evidence: `reports/github/09-repository-architecture-cleanup.md`.
- Next: report final branch SHA and CI result to `00_PM`; wait for separate
  Product Owner decision before any merge or publication.

## Current Status — Final Closure (2026-09-25)

- `NetEase`: DONE; `MediaRemote Bridge`: DONE; `Auto Detect`: DONE.
- v0.8.0 build 18: FROZEN / READY FOR RELEASE REVIEW.
- Product Owner final GUI confirmation: PASS for current/restart lyrics, Notch
  Mode, custom color persistence, Hide on Hover, Auto Detect combinations and
  ownership/fallback/stale clearing, Sleep/Wake, and network recovery. Details
  and durations were not supplied; no steps or numbers are inferred.
- Seek forward/back: Manual PASS; no numeric latency supplied.
- 60-minute continuous-playback soak: PASS for playback/helper stability.
  Samples at start/15/30/60 minutes; one app, watchdog, and Perl helper; no
  crash, restart, helper loss, or orphan. Evidence is in
  `/tmp/notchmuse-build18-soak.log`.
- Build: arm64, ad-hoc signed, no Team ID. Developer ID/notarization/stapling
  and clean-new-user distribution assessment remain release-review risks.
- Executable SHA-256:
  `4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992`.
- DMG SHA-256:
  `4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`.
- No merge to main, push, tag, or public release was performed by this task.

## Historical Kickoff Snapshot — 2026-09-25 (build 16)

- Verified requested startup SHA `dee834f533812aac3e1dcab83f5d62a008d6a906`;
  `codex/netease-production-candidate` resolves to the same commit. This
  workspace is detached at that SHA and clean at kickoff.
- Installed `/Applications/NotchMuse.app` is `0.8.0` build `16`, arm64,
  ad-hoc signed, with no Team ID. Executable SHA-256 is
  `16606dd8756c0b33f5a173dc9a2d6a5b15aea0d46a72327f2e5359b18ea0ea38`;
  it is not yet attributable to the requested Git SHA. One NotchMuse process,
  watchdog, and Perl bridge process are running.
- A live NetEase sample from the installed app reports `History`, artist
  `88rising/Rich Brian`, native ID
  `409DF800-D582-445C-9BC5-742A9D2F45C9`, playing at 64.89s/207.35s; the
  lyric is visibly rendered. This was the kickoff observation; it is superseded by the final closure at the top of this file.
- At kickoff no implementation changes had been made. Next: run candidate
  build/self-tests and available automated checks, inspect installed candidate
  behavior, then record each GUI/environment gate as PASS or blocked with
  evidence.

## 2026-09-25 Seek Latency Update

- Root cause: `MenuBarController` polls once per second, while
  `NetEaseMusicAdapter` refreshes the bridge position only after two seconds.
  The same-track convergence path immediately accepts playback updates, so the
  300ms identity debounce is not involved. Lyric display recalculates from the
  new position as soon as the adapter returns. The observed delay was the
  two-second refresh threshold plus poll alignment and bridge response time.
- Measured one-shot bridge `get` cost: 20 calls median 23.4ms / P95 28.8ms / CPU
  0.320s; a later 30-call sample median 19.6ms / P95 30.2ms / CPU 0.429s.
  At 60 calls/minute this is about 0.86 CPU seconds/minute; the persistent
  watchdog and stream helper count is unchanged.
- TDD regression checks first failed on the existing two-second threshold,
  then passed after reducing the existing position-refresh interval to one
  second. They also cover lyric clock resynchronization after a large position
  jump, stable track identity, and no repeat lyric fetch.
- Candidate `0.8.0` build `18` was built and installed from source HEAD
  `dee834f533812aac3e1dcab83f5d62a008d6a906` plus the local seek fix. The
  executable SHA-256 is
  `4b39029a509f05c6d5521781944b1e61e31b1de67c229c9c7f55cc0b2b481992` and DMG
  SHA-256 is `4a7af27c13a2a0ae90e50aefc6f8484d0162cdc08c3bef0b192e29fdda5968bb`.
  Debug and Release self-tests, deep code-signature verification, DMG verify,
  localization parity, and `git diff --check` pass. Build is arm64 and
  ad-hoc-signed without a Team ID.
- Lifecycle process gate: NetEase and NotchMuse restarted separately on build
  17, then simultaneously on build 18. The old bridge helpers exited and each
  restart created exactly one watchdog/Perl pair. After the combined restart,
  NetEase metadata returned within four seconds as `Night` / `keshi`, native ID
  `AF0CDF83-FF51-4F08-A048-5A396B8A588B`, paused.
- Product Owner confirms build 18 forward/back seek Manual PASS; no numeric
  latency was supplied.
- Valid Build 18 continuous-playback soak began 2026-09-25 20:46:21 CST after
  bridge confirmation `playing=true`. Start sample: one NotchMuse (PID 43342),
  one watchdog (43357), one candidate Perl stream (43358); CPU/RSS:
  9.5%/38,560 KB, 0.0%/1,552 KB, 0.0%/19,120 KB. NetEase owner is
  `com.netease.163music`, title `再等冬天(Memories)`, artist `h3R3`, native ID
  `868213FA-07FD-4729-B4E3-14EBBB607D97`, playing. The 20:40 paused sample is
  invalid and retained at `/tmp/notchmuse-build18-soak-paused-presample.log`.
  Lyrics/stale state could not be visually checked because the desktop is in
  Status Bar Mode and the app surface is obscured. No crash or helper orphan at
  valid start. Valid sample log: `/tmp/notchmuse-build18-soak.log`; 15-minute sample at
  21:01:24: one app/watchdog/Perl each, CPU/RSS 5.8%/36,464 KB,
  0.0%/1,712 KB, 0.0%/19,200 KB. NetEase still playing `Lonely` / Nana, ID
  `224190D7-032E-4220-9E87-3196544CC388`. No crash, helper loss/orphan, or
  restart observed. 30-minute sample at 21:16:24: one app/watchdog/Perl each,
  CPU/RSS 5.5%/42,864 KB, 0.0%/1,728 KB, 0.0%/19,104 KB. NetEase playing
  `呼吸有害` / 邓智伟, ID `DBE02D7B-B22F-46A1-9D9B-92BECB5F0A05`.
  60-minute sample at 21:46:24 recorded NotchMuse PID 43342
  at 6.8% CPU / 38,928 KB RSS, watchdog PID 43357 at 0.1% / 1,728 KB, and
  Perl PID 43358 at 0.0% / 19,008 KB; one of each, no crash/restart/helper
  loss/orphan. NetEase was playing `被你改变的那部分我` / 梁森田, native ID
  `9DC79DE3-1328-429C-855C-4A01CC4F816E`.
- Product Owner final GUI confirmation: PASS for current/restart lyrics, Notch
  Mode, custom color persistence, Hide on Hover, Auto Detect combinations and
  ownership/fallback/stale clearing, Sleep/Wake, and network recovery. No
  per-step details or durations were supplied. Candidate status: FROZEN / READY
  FOR RELEASE REVIEW.

Last updated: 2026-09-25 (build 18 final closure)

## Historical Status at build 15 (superseded by Current Status above)

- v0.8 Stability Fix Sprint implementation and focused QA are complete;
  release remains prohibited.
- Integration branch: `codex/netease-production-candidate`; audited product/QA
  tip `4877b61` was backed up before this Git Sync documentation update.
- `01_APP`, `04_UX`, and `07_QA` are merged and archived.

## Historical Git Sync Status at prior backup

- Remote: `https://github.com/Xiye88/NotchMuse.git`.
- `origin/main`: `8a45e2254929ee97910ba94d1e698e44d5e2205f`.
- Development branch: `codex/netease-production-candidate`.
- Audited candidate commit: `4877b6126f0889d65db65f5b08995be2db90021b`.
- Remote development branch after backup:
  `origin/codex/netease-production-candidate` at the same commit.
- Push result: SUCCESS. Branch and upstream were created on `origin`; `main`,
  tags, and GitHub Releases were not changed.
- Candidate versus `origin/main`: ahead 35, behind 0; linear history, no
  divergence at audit time.
- Apple Music is already on `origin/main` (`56c9f40`, `39b77b9`, `e3c2e53`).
- NetEase, bundled MediaRemote, Auto Detect, v0.8 Settings/UX, and Stability QA
  are pushed only on the development branch, not `main`.
- Latest public release remains v0.6.1. `main` contains later evidence/docs but
  no v0.7 or v0.8 public release.
- Audit evidence found no push to the current `origin` after 2026-08-31 before
  this backup. Any prior statement that yesterday's v0.8 work was pushed was
  inaccurate; it was committed locally only.
- Future PM records must include `Branch`, full `Commit SHA`, `Remote`, and
  command `Push result`; the word "pushed" alone is not sufficient.

Local-only items intentionally excluded from the Candidate backup:

- Dirty root worktree `codex/netease-experimental-runtime`: four experimental
  bridge files/comparison notes plus a Wrong Version feedback change and stale
  September 6 planning-document edits. Preserved unchanged for later triage.
- `codex/netease-visible-lyrics-e2e` commit `8a3295e`: standalone QA validator;
  exact commit is local only and is not required by the shipped app runtime.
- Short-lived APP/UX/QA task branch tips are not remote refs. Their delivered
  content is integrated and pushed through candidate commits `28d7a3b`,
  `46dc4f5`, `daff724`, `190fee6`, and `7423dcc`.

## Completed

- Auto Detect now samples real adapter state, uses playback freshness/activity,
  and does not claim a player merely because its app is open.
- NetEase state rejects stale asynchronous results and out-of-order events,
  handles reused native IDs, and expires after bridge data stops refreshing.
- Settings persist Auto, Spotify, Apple Music, and NetEase selections.
- Stop behavior covers pause, player exit, and source switching; `Hide` remains
  the default and `Keep` preserves the last lyric without scrolling.
- Notch UX supports None/Black/Custom backgrounds, hover hiding, arbitrary
  lyric color plus presets, editable numeric controls, and functional Custom
  Width down to 180 points.

## Changed Files

- Player/state: `MusicPlayerAdapter.swift`, `NetEaseMusicAdapter.swift`,
  `NetEaseEventConverger.swift`, `MenuBarController.swift`.
- UX: `SettingsWindowController.swift`, `OverlayLyricsWindow.swift`,
  `BrandStyle.swift`.
- Regression coverage: `SelfTests.swift`; release notes: `CHANGELOG.md`.

## Verification at focused QA (historical, superseded by final status above)

- Integrated Debug build + self-tests: PASS.
- Integrated Release build + self-tests: PASS.
- English/Chinese strings lint and key parity: PASS.
- `git diff --check`: PASS.
- Focused QA: PASS with environment blockers; 0 observed FAIL.
- Real NetEase passed Auto play/pause, natural/manual next, previous, seek,
  restart, metadata/ID/lyric refresh, Hide/Keep, and Notch background checks.
- Real Apple Music and Spotify playback passed with visible synced lyrics.
- With both players active, Auto selected the latest Spotify activity and
  returned to the still-playing Apple Music within about two seconds after
  Spotify paused.
- The live Settings window exposed all four player choices; numeric Enter and
  Auto/Compact/Standard/Wide/Custom width controls passed direct interaction.
- The six lyric-color choices, Blue/Custom selection, and native macOS color
  panel opening passed direct interaction.

## Historical Next Actions at build 15

- Remaining gates: custom-color change/live-preview/restart-persistence loop,
  pointer Hover enter/leave, Sleep/Wake, and network recovery.
- Decide and execute those environment-dependent gates before entering the
  Release Sprint. Do not push, tag, or publish.

## Historical Project State at build 15

- Current version: `0.8.0` candidate, build `15`; not publicly released.
- Current branch: `codex/netease-production-candidate`; APP and UX development
  changes are being integrated and verified.
- Completed: Spotify, Apple Music, and NetEase adapters; Auto Detect default;
  manual player overrides; deterministic Playing/Paused/Stopped behavior;
  native-track stale lyric clearing; NetEase Settings regression coverage;
  Notch `None / Black / Custom` background modes and Hide on Hover setting;
  verified local DMG and checksum.
- Completed locally: old build 7 and build 14 app bundles were moved to Trash;
  `/Applications/NotchMuse.app` is now build 15; Spotlight and LaunchServices
  expose one primary launch entry; its executable matches the build-15 hash;
  Player Source is set to Auto Detect.
- Unfinished: complete build-15 real-player, Notch GUI, lifecycle/resource,
  and clean-install regression; Developer ID signing/notarization remains
  unavailable.
- Current blocker: build 15 is ad-hoc signed and real-player/clean-install QA
  is incomplete. The local multi-version conflict is resolved.
- Current sprint: v0.8 Stability Fix Sprint. P0 App work must validate and
  harden NetEase restoration, playback-based Auto Detect, and NetEase state
  convergence. P1 UX work must finish controls and fix Custom Width.
- QA is paused until P0 and P1 development tasks merge. Public push, tag, and
  GitHub Release are prohibited during this sprint.

## Historical Active Execution at focused QA (superseded)

- `01_APP`: archived after merge (`28d7a3b`).
- `04_UX`: archived after merge (`46dc4f5`).
- `07_QA`: archived after focused QA report (`daff724`).
- `00_PM`: integration, verification, and handoff updates.

The sections above are historical backup state. Older build-14 details below are
also historical evidence only; see Current Status at the top for the live state.

## Historical Build 15 Update

Current status:

- P0 Auto Detect, Settings regression, stopped-player policy, paused scrolling,
  and native track identity clearing are merged on
  `codex/netease-production-candidate`.
- Local `0.8.0` build `15` passes Release self-tests, deep code-signature
  verification, DMG verification, and checksum verification.
- DMG SHA-256:
  `215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
- The app is arm64 and ad-hoc signed with no Team ID; Gatekeeper rejects it.
- Public push, tag, and GitHub Release have not started.
- P0.1 local install conflict is resolved: only
  `/Applications/NotchMuse.app` build 15 is Spotlight-visible. Old build 7 and
  build 14 app bundles are recoverable from Trash.
- P0.2 focused runtime passed: with Auto Detect selected and only NetEase
  running, the owner was `com.netease.163music` with active playback and a
  current lyric was visibly rendered. Multi-player real switching remains a
  build-15 QA gate.

Pending confirmation:

- Real Spotify, Apple Music, and NetEase Auto Detect/state regression.
- Notch GUI regression, lifecycle/resource observation, and clean-install QA.
- Product Owner approval immediately before any public release.

Key files: `PROJECT_STATUS.md`, `ROADMAP.md`, `TASK_BOARD.md`, `CHANGELOG.md`.
Next step: run the remaining real-player and release gates on build 15.
Do not repeat: build 9-14 investigations or the completed P0 implementation.

The remaining sections preserve the detailed build-14 handoff evidence. Where
they conflict with the block above, the build-15 update and current status
documents take precedence.

This file preserves the detailed implementation handoff. Current sprint facts
are synchronized in `PROJECT_STATUS.md`, `TASK_BOARD.md`, and `ROADMAP.md`.

## 1. 项目目标

NotchMuse 是一款 macOS 菜单栏歌词应用，目标是在不打断用户当前工作流的
情况下，为正在播放的音乐提供稳定、及时、低干扰的同步歌词。

当前核心功能：

- 支持 Spotify、Apple Music、网易云音乐当前歌曲读取。
- 通过统一的 `NowPlayingTrack` 和 `MusicPlayerAdapter` 接口驱动歌词链路。
- 从多个歌词 Provider 并发获取歌词，经过严格 Matcher 后选择可接受结果。
- 支持 Status Bar Mode 和 Notch Mode。
- 支持暂停、恢复、切歌、进度跳转、播放器重启、App 重启、Sleep/Wake 和
  网络恢复。
- 支持中英文界面、播放器选择、显示模式、字体、颜色、透明度、背景模式和
  Hover 行为设置。
- 提供用户主动触发的歌词问题反馈入口，不包含 telemetry。

产品原则：真实用户体验优先；不得以 Provider 命中代替 UI 可见歌词通过；
Production Matcher、Provider priority 和新平台必须有独立证据 Gate。

## 2. 当前版本状态

### v0.8 Production Candidate

- 工作目录：`/Users/carlos/Documents/歌词/.worktrees/netease-production-candidate`
- 分支：`codex/netease-production-candidate`
- 当前 HEAD：`c2d862b`
- Candidate：`0.8.0` build `14`
- App：`dist.noindex/NotchMuse.app`
- DMG：`dist.noindex/NotchMuse.dmg`
- DMG SHA-256：`d574b84dac10b30a5cb9a58ca9b967e27f3bcf334ee013180caab7f5a0b4bada`
- 独立安装位置：`/Applications/NotchMuse v0.8 Candidate.app`
- 稳定版 `/Applications/NotchMuse.app` 未被覆盖。
- 当前分支尚未 merge、push、tag 或创建 GitHub v0.8 Release。

### 已完成

- Spotify：现有 Production 支持保持稳定；v0.6 长时间与恢复测试已归档。
- Apple Music：Production 支持已发布；Automation denial/re-grant、网络恢复、
  Sleep/Wake 和 Spotify regression 已通过。
- NetEase：内置固定版本 MediaRemote Bridge、Adapter、事件收敛、配置持久化、
  helper 生命周期管理和歌词链路已实现。
- Lyrics pipeline：网易云安装版 build 13 完成 `20/20` UI 可见歌词矩阵；
  build 14 的 seek 时间轴修复完成真实验证。
- Notch Mode：默认透明背景；支持 `None / Black / Custom`，默认
  Hide on Hover 开启。
- Settings：NetEase 选择可跨 App 重启保存；播放器、显示和 Notch 背景设置
  已接入 UserDefaults。
- Lifecycle：用户确认 Sleep/Wake、断网恢复均通过且无旧歌词残留。
- Release artifact：build 14 Release self-test、codesign deep verify 和
  `hdiutil verify` 均通过；Bridge framework、Perl script、test client 和
  watchdog 均打包在 App Bundle 内。

### 未完成

- 未获得 Product Owner 的公开发布授权，因此不得 push/tag/release。
- build 14 只新增 seek 位置校准；尚未在 build 14 上重新执行完整 20 首矩阵、
  60 分钟生命周期和 Spotify/Apple Music smoke regression。build 13 的 20 首
  矩阵已通过，seek 修复仅影响 NetEase 位置读取。
- 尚未在一台真正干净的 Mac 或新用户账户完成 Gatekeeper、TCC、安装、三播放器
  和歌词恢复的完整首次用户流程。
- App 仍为 ad-hoc signed GitHub Beta；Developer ID signing、notarization 和
  stapling 未完成。
- App 主程序当前为 arm64；Bridge framework/helper 为 universal。Intel App
  支持未实现。
- `PROJECT_STATUS.md`、`TASK_BOARD.md`、`ROADMAP.md` 尚未同步 build 14 的最终
  状态；本交接文件暂为最新事实源。

## 3. 当前代码架构

代码根目录：`MenuBarLyrics/Sources/MenuBarLyrics/`

### Player Adapter

- `MusicPlayerAdapter.swift`：统一协议、`PlayerSource`、`NowPlayingTrack`、
  `MusicPlayerSnapshot` 和 Spotify Adapter。
- `SpotifyReader.swift`：通过 Spotify Apple Events 读取当前歌曲。
- `AppleMusicAdapter.swift`：读取 Music.app 并映射为统一播放状态。
- `NetEaseMusicAdapter.swift`：消费 Bridge 事件，维护缓存状态、本地播放时钟，
  每 2 秒校准一次真实位置以支持 seek。
- `NetEaseEventConverger.swift`：对快速变化的网易云 metadata 做 300ms 收敛，
  清理非网易云 owner 和 stale state。
- `MediaRemoteBridge.swift`：从 App Bundle 启动 Perl bridge，负责 health/get/
  stream、JSON decode、timeout 和进程退出。
- Bundle 资源：`MenuBarLyrics/Vendor/MediaRemoteBridge/`。

### Lyrics Provider

- `LRCLIBLyricsSource.swift`
- `LRCMuxLyricsSource.swift`
- `NetEaseLyricsSource.swift`
- `QQMusicLyricsSource.swift`
- `KugouLyricsSource.swift`
- `SodaMusicLyricsSource.swift`
- `LyricsHTTP.swift`：统一 HTTP 响应检查。
- `LyricParser.swift`：将 LRC 转为 `[LyricLine]`。

`NetEaseLyricsSource` 包含两个严格限定的播放器兼容处理：短试听 duration
fallback，以及网易云 MediaRemote `/` 分隔多歌手的格式转换。它们不改变通用
Matcher。

### LyricsClient 与 Matcher

- `LyricsClient.swift`：并发请求 Provider、返回首个非空结果、缓存歌词和记录
  选中 Provider。
- `TrackMatcher.swift`：严格 title/version/artist/duration 打分、threshold、
  ambiguity gap 和诊断。
- Production Matcher 当前冻结。v0.7 Evidence Gate 为 `NO-GO`，不得修改
  ranking、threshold、weights 或 Provider priority。
- `LyricClock.swift`：根据播放位置选择当前歌词行和行内进度。

### UI

- `MenuBarController.swift`：应用主协调器；每秒读取 Adapter，触发 LyricsClient，
  管理歌词状态、Status Bar、Notch Overlay 和设置回调。
- `OverlayLyricsWindow.swift`：Status Bar/Notch 窗口、布局、透明背景、滚动、
  Hover 隐藏和多屏定位。
- `BrandStyle.swift`、`ScrollState.swift`、`MenuBarSafety.swift`：显示辅助逻辑。

### Settings

- `SettingsWindowController.swift`：设置 UI 和 `AppPreferences`。
- `AppLocalization.swift` 与 `Resources/*/Localizable.strings`：英文和简体中文。
- 当前播放器选择保存在 `PlayerSource`；当前没有“自动判断活跃播放器”的设置。

### 运行关系

```text
Spotify / Apple Music / NetEase
  -> MusicPlayerAdapter
  -> NowPlayingTrack
  -> MenuBarController
  -> LyricsClient
  -> Provider responses
  -> TrackMatcher
  -> LyricParser / LyricClock
  -> Status Bar / Notch Mode
```

网易云专用链路：

```text
/usr/bin/perl
  -> bundled MediaRemoteAdapter.framework
  -> MediaRemoteBridge
  -> NetEaseEventConverger
  -> NetEaseMusicAdapter
  -> NowPlayingTrack
```

构建入口：`scripts/build_release.sh <version> <build>`。Self-test 位于
`SelfTests.swift`，运行命令：

```bash
cd MenuBarLyrics
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
CLANG_MODULE_CACHE_PATH=/tmp/notchmuse-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/notchmuse-swift-cache \
swift build -c release
.build/release/NotchMuse --self-test
```

## 4. 已解决 Bug

- `ff8ccb9`：稳定网易云 metadata、持久化播放器选择、默认透明 Notch 背景和
  Hide on Hover。
- `e2a5fd6`：Bridge stream 的 elapsed position 固定时，本地单调时钟继续推进
  歌词，不再卡在首行。
- `2567214`：网易云 60 秒试听 metadata 不再因 duration 被严格 Matcher
  全部拒绝；仅允许唯一严格身份候选。
- `188582b`：将上述兼容覆盖到真实出现的 30 秒试听 metadata。
- `f98a01a`：网易云 `/` 分隔多歌手可与 Provider 的 artist array 严格匹配。
- `51ac294`：Notch 背景明确为 `None / Black / Custom`，默认无背景。
- `c2d862b`：用户跳转播放进度时每 2 秒校准真实位置，歌词随 seek 同步。
- `ade26f7`：NotchMuse 退出后 watchdog/Perl helper 正确结束，无孤儿进程。
- 快速切歌 metadata 经 300ms 收敛后只提交最终稳定歌曲，避免重复歌词请求和
  持续 stale lyrics。
- NetEase 配置跨 App 重启保留；build 13 的 20 首安装版可见歌词矩阵为
  `20/20 PASS`。

## 5. 当前未解决问题

### 1. 播放器自动识别

当前播放器由用户在 Settings 手动选择。`DisplayTarget` 的 Auto Detect 只负责
屏幕选择，不是播放器选择。Spotify、Apple Music、NetEase 同时打开时，App
不会自动切到最近活跃且正在播放的播放器。若实现，必须先定义 deterministic
owner policy、暂停优先级、切换 debounce 和 stale clearing；不得依赖未经验证的
全局 MediaRemote owner 作为 Spotify/Apple Music 的替代路径。

### 2. NetEase regression

- build 14 seek 已真实通过：位置从约 `41s` 跳到 `138s`，歌词约 2 秒内同步。
- build 14 尚未重跑完整 20 首、60 分钟、Sleep/Wake 和 network matrix。
- Bridge 依赖 private MediaRemote 行为；macOS 更新可能破坏它。
- `mediaremoteagent` 曾出现一次空 metadata，之后恢复；产品不应自动 kill 系统
  进程。
- 每 2 秒 `get` 是 stream 不报告 seek 时的最小校准；需在长时间测试中确认
  CPU、helper 启动次数和请求稳定性。

### 3. Settings regression

- `None / Black / Custom` 已实现并有 self-test，但 build 14 尚未完成全量 GUI
  click-through、语言切换和 fresh-install persistence QA。
- 必须确认切换 `Custom` 后 Color Well 可见，切回 `Black/None` 后隐藏，并且
  重启后模式与颜色保持。
- NetEase 选择重启持久化已通过。

### 4. Notch UX

- 默认无背景和当前歌词渲染已通过目标截图检查。
- Hide on Hover 默认开启，但 build 14 尚未完成最终鼠标点击穿透/显示恢复矩阵。
- 已知 P1：Spotify 恢复播放后 Notch Mode 偶尔短暂变成 lyric-only 高度，约
  1-2 秒后恢复 Song + Lyric。当前不阻塞 Beta，但需保留复现记录。
- Status Bar 公开截图左侧有裁切问题，只影响文档素材，不是运行时功能。

### 其他发布风险

- unsigned Beta 会触发 Gatekeeper；正式体验仍缺 Developer ID/notarization。
- v0.8 公开 Release 尚未创建。
- Production Matcher、metadata enrichment 和 Provider order 均保持冻结。

## 6. Workspace Registry

编号唯一，不得新建重复编号。

| Workspace | 状态 | 职责与交接状态 |
| --- | --- | --- |
| `00_PM` | Active | 当前 PM 交接中。新 PM 读取本文件后接管 Gate、优先级、merge/release 决策。 |
| `01_APP` | Done | v0.8 Adapter、Bridge、metadata、seek 和 lifecycle 第一轮修复完成。后续仅处理明确回归。 |
| `02_RELEASE` | Done | build 14 App/DMG 已生成并验证；公开 push/tag/release 未授权。 |
| `03_LAB` | Done | build 13 可见歌词验证已由 QA 完成；Matcher/metadata 深度实验阶段已关闭为 NO-GO。 |
| `04_UX` | Done | Notch 背景模式实现完成；build 14 最终 GUI regression 列入下一 Gate。 |
| `05_MATCHER` | Archived | v0.7 Evidence Gate 为 NO-GO；禁止继续调整 Production Matcher。 |
| `06_DOCS` | Active | 需要在最终 Gate 后同步状态文档和准备 v0.8 Beta 文档；当前不得写已发布。 |
| `07_QA` | Done | build 13 安装版 `20/20` 可见歌词矩阵通过；build 14 seek 由 00_PM 真实验证通过。 |

## 7. 下一阶段 Roadmap

### P0

1. 在 build 14 上做一次聚焦 regression：至少 10 首 NetEase 可见歌词、两次
   进度前跳/后跳、暂停/恢复、App 重启，确认 2 秒校准没有重复歌词请求或 stale。
2. 对 build 14 做 30-60 分钟资源观察，确认周期性 `get` 不产生 helper orphan、
   CPU/RSS 增长或进程堆积。
3. Spotify 与 Apple Music 各做一次最小 smoke：播放、切歌、暂停/恢复、可见歌词。
4. 完成 Settings 和 Notch 的 build 14 GUI regression。
5. Gate 通过后由 00_PM 给出 `GO / CONDITIONAL GO / NO-GO`。只有 Product Owner
   明确授权，才可 merge、push、tag 和创建 GitHub v0.8.0 Beta Release。

### P1

1. 设计播放器自动识别 policy 和离线状态机测试；先写决策规则，不直接接入生产。
2. 完成真正 clean Mac/new-user 的安装、Gatekeeper、TCC 和首次播放流程。
3. 评估 Developer ID signing/notarization；缺少证书时明确保持 GitHub unsigned
   Beta，不伪造通过。
4. 修复或接受 Spotify resume 后 Notch 高度短暂变化的 P1 风险。
5. 同步 `PROJECT_STATUS.md`、`TASK_BOARD.md`、`ROADMAP.md`、CHANGELOG 和 Release
   Notes，但不得公开内部 Coverage 数字。

### P2

1. 根据真实用户反馈决定是否做 Universal Binary / Intel。
2. 更新公开截图和 Demo 素材。
3. 继续 Benchmark 仅作健康监测；无新人工真值证据时不得重开 Matcher 优化。
4. 新音乐平台继续延后，不在 v0.8 Critical Fix 范围内开发。

## 8. 新 PM 启动说明

新 PM 启动后必须：

1. 首先读取本文件，不要从旧 conversation 或旧状态文档重新推断当前状态。
2. 使用 worktree
   `/Users/carlos/Documents/歌词/.worktrees/netease-production-candidate`，不要在 dirty
   main workspace 开发，也不要重做 Direct MediaRemote 调查。
3. 先运行 `git status --short --branch` 和 `git rev-parse HEAD`，确认分支为
   `codex/netease-production-candidate`、HEAD 不早于 `c2d862b`。
4. 保留当前最小修复边界：不得修改 Production Matcher、Provider priority、
   Spotify 或 Apple Music 架构，除非出现新的可复现回归。
5. 先完成 Roadmap P0 Gate，再讨论发布。公开发布属于需 Product Owner 明确确认
   的操作。
6. 不要重复 build 9-13 的旧失败调查；从 build 14 和 `c2d862b` 继续。

本交接文件创建完成后，原 PM 应停止开发，仅将文件位置和摘要交给 Product Owner。

## Repository Architecture Audit Handoff — 2026-09-25

- Audit baseline verified: `origin/codex/netease-production-candidate` and
  `HEAD` both resolve to `dee834f533812aac3e1dcab83f5d62a008d6a906` after fetch.
- Worktree started clean and detached at the requested baseline.
- Current phase: repository architecture audit; runtime and package structure
  remain unchanged. CI proposal is additive only.
- Deliverables in progress: `reports/github/09-repository-architecture-audit.md`
  and `.github/workflows/ci.yml`.
- Open boundary: no architectural cleanup until `00_PM` supplies Candidate
  Freeze SHA; then fetch it and create `codex/repository-architecture-cleanup`
  from that exact SHA.
- Do not repeat: baseline SHA/ref verification.
- Audit report complete with P0-P2 findings, test/CI plan, README proposal,
  documentation map, migration risks/order, and pre-v0.8 freeze boundaries.
- Additive CI workflow is in place; local syntax, localization, Vendor hash,
  and diff-whitespace checks pass. GitHub-hosted build execution is pending.
- The report is force-added because this machine's `.git/info/exclude`
  suppresses all `reports/**/*.md`; no exclude rule was changed.
- Installed and `dist.noindex` artifacts are v0.8.0 build 16; older project
  status text that still names build 15 is documentation drift. This audit
  checkout is detached at baseline SHA
  `dee834f533812aac3e1dcab83f5d62a008d6a906`.
- Completed verification: `swift build --package-path MenuBarLyrics -c release`
  and `MenuBarLyrics/.build/release/NotchMuse --self-test` passed; workflow YAML,
  shell/Perl syntax, 102 localization keys, Vendor hashes, and `git diff --check`
  passed. Full DMG wrapper not run because it deletes `dist.noindex` first.
- Next: report CI proposal to `00_PM`; wait for Candidate Freeze SHA before any
  architecture cleanup. No runtime or Package target changes made.
