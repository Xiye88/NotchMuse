# NotchMuse Project Handoff

Last updated: 2026-09-23 (build 15)

## Current Project State

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

## Active Execution

- `01_APP`: P0 NetEase settings persistence, playback-based Auto Detect, and
  NetEase play/pause/previous/next/seek/restart stability.
- `04_UX`: P1 Notch defaults, Hover Hide, stopped behavior UI, full lyric
  color picker with presets, editable numeric controls, and Custom Width.
- `07_QA`: archived until both development workspaces are complete.
- `00_PM`: integration, verification, and handoff updates.

This section is the canonical current state. Older build-14 details below are
historical evidence only.

## Build 15 Update

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
