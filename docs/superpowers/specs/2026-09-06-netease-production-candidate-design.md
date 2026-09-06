# NetEase Production Candidate Design

## Goal

将已验证的 LyricsX-compatible MediaRemote Bridge 作为固定版本资源随
NotchMuse 分发，在不修改歌词 Matcher、Provider 顺序、Spotify 或 Apple Music
读取逻辑的前提下，为网易云音乐提供可关闭、可恢复、可验证的 Production
Candidate 播放器接入。

## Scope

本阶段包含：Bundle 打包、Bridge 进程管理、网易云 Adapter、播放器选择、
事件收敛、双语状态、真实 UI 与生命周期验证、第三方声明。

本阶段不包含：Matcher/Provider 变更、新歌词源、其他播放器、UI 重设计或
未经 Gate 的 v0.8 发布。

## Dependency Pin

- Repository: `MxIris-LyricsX-Project/mediaremote-adapter-framework`
- Commit: `6bbb7d30f9ddb209a583fa509b9ca145df97f502`
- License: BSD-3-Clause
- Framework: `MediaRemoteAdapter.framework`, universal `arm64 + x86_64`
- Helper: `MediaRemoteAdapterTestClient`, universal `arm64 + x86_64`
- Script: `mediaremote-adapter.pl`
- Runtime host: macOS system `/usr/bin/perl`

仓库保存固定构建产物、LICENSE、版本清单和 SHA-256。维护者可用独立脚本从
固定 commit 重建；最终用户不需要 Homebrew、CMake、终端或手工 helper。

## Bundle Layout

```text
NotchMuse.app/Contents/Resources/MediaRemoteBridge/
├── MediaRemoteAdapter.framework
├── MediaRemoteAdapterTestClient
├── mediaremote-adapter.pl
├── LICENSE
└── VERSION.json
```

Production 只通过 `Bundle.main.resourceURL` 解析此目录。依赖注入路径只用于
SelfTests；正式初始化不存在开发机绝对路径 fallback。

Build 在复制后恢复 helper/script 执行权限，先签 framework 和 helper，再签
App。构建验证必须检查文件存在、架构、权限、版本清单和 `codesign --verify`。

## Runtime Architecture

```text
/usr/bin/perl
  -> bundled mediaremote-adapter.pl
  -> bundled MediaRemoteAdapter.framework
  -> stdout JSON envelope
  -> MediaRemoteBridge
  -> NetEaseEventConverger
  -> NetEaseMusicAdapter
  -> MusicPlayerSnapshot / NowPlayingTrack
  -> existing LyricsClient
  -> existing Status Bar / Notch Mode
```

`MediaRemoteBridge` 只负责资源校验、带 timeout 的 health/get、单一 stream、
逐行 JSON 解码、一次受限恢复和同步 shutdown。业务层不能直接访问私有
MediaRemote。

`NetEaseMusicAdapter` 只接受 `com.netease.163music`。来自 Spotify 或 Apple
Music 的全局事件会清除网易云当前 Track，而不是抢占用户已选 Player。

## Event Convergence

真实 stream 证明切歌时会产生 3-4 条过渡 snapshot。采用以下最小规则：

1. 完全相同事件直接丢弃。
2. 同一 track identity 的 play/pause/position 立即更新。
3. 新 track identity 暂存，等待连续两次相同 identity，或等待最后事件后
   `300 ms` 静默，再提交最终状态。
4. 非网易云 owner 立即清除已提交网易云状态，避免 stale lyrics。
5. 不使用 title fuzzy、弱相似合并或 Matcher 规则。

该窗口小于当前一秒 UI poll interval，不额外引入可感知长延迟。

## Lifecycle And Recovery

- Adapter 首次启用执行 `healthCheck(timeout: 5s)`，失败返回 `.unavailable`。
- health 通过后先 `get` 建立快照，再启动唯一 stream。
- stream 异常退出只自动重启一次；第二次失败后保持 unavailable，直到用户
  重新选择播放器或重新启动 App，禁止无限 retry。
- Player 切换、Controller stop、App quit 和 Adapter deinit 都调用同步
  `shutdown()`，终止 Perl 并关闭 FileHandle。
- 网易云未运行返回 `.closed`；已运行但不是当前 owner 返回 `.stopped`。
- 网络失败只影响现有 LyricsClient，不重启 Bridge。

## Settings And UX

`PlayerSource` 增加 `.netEaseMusic`，默认仍为 Spotify。Settings 继续使用现有
Pop-up，不自动切换当前 Player。

英文显示 `NetEase Cloud Music`，简体中文显示 `网易云音乐`。health 失败显示
明确的兼容性错误，不使用 Apple Music Automation 权限文案。

## Compliance

`THIRD_PARTY_NOTICES.md` 和 App Bundle 内 LICENSE 记录 framework 来源、commit
和 BSD-3-Clause 条款。README 只增加简短 acknowledgements，不公开实验过程。
若未来修改 MPL-2.0 LyricsX 源文件，必须重新评估文件级开源义务；本设计不复制
LyricsX 源码。

## Verification Gates

自动 Gate：SelfTests、Swift 6 build、Bundle 内容/权限/签名、fresh-path smoke、
Bridge crash/restart、无 orphan、现有 Spotify/Apple Music SelfTests。

真实 Gate：20 首 UI 链路、60 分钟、30 次切歌、10 次暂停恢复、三次双方重启、
双语和显示模式切换、Sleep/Wake、网络恢复、20 次多播放器切换、CPU/memory/
FD/process 检查。

只有全部 P0/P1 通过，且 License 完成，Production Gate 才能为 GO。仅 Minor/P2
可以给 CONDITIONAL GO；任何 crash、持续 stale lyrics、串台或 helper 失控均为
NO-GO。

## Release Boundary

Production Gate 前不创建 v0.8 tag、DMG 或 GitHub Release。Gate 为 GO 或允许的
CONDITIONAL GO 后，才执行 v0.8.0 Beta release 流程并从 GitHub 重新下载验证。
