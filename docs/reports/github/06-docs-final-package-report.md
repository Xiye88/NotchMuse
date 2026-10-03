# GitHub Release Final Package

Task: 06_DOCS Final Beta Release Preparation

Status: Completed

Priority: P0

## Findings

- 已完成 README Final 最小必要文档收口，README 面向 GitHub 用户改为英文。
- README 已覆盖 GitHub Open Source Beta 所需核心内容：
  - Features
  - Requirements
  - Installation
  - unsigned macOS security warning / Control-click Open / Open Anyway
  - Screenshots planned paths
  - Demo GIF planned path and capture flow
  - Usage
  - Permissions
  - Privacy
  - Architecture
  - Build From Source
  - Tests
  - Known Issues
- Architecture 介绍已加入 README，覆盖 `SpotifyReader`、`LyricsClient`、`TrackMatcher`、`LyricClock`、`LyricParser`、`ScrollState`、`MenuBarController`、`OverlayLyricsWindow`、`SettingsWindowController`、`AccessibilityManager` 的职责。
- Installation 已按当前 Open Source Beta 策略调整：Developer ID / notarization 不再作为当前发布阻塞项，只标记为未来 Distribution Phase。
- CHANGELOG 做了最小整理：`0.2.2 Beta` 已统一为 `0.2.2-beta`。
- 未修改 App 逻辑，未触碰 Swift 代码。

## Problems Found

- 实际截图文件尚未存在，README 当前使用计划路径：
  - `docs/assets/screenshots/status-bar-right.png`
  - `docs/assets/screenshots/notch-mode-song-lyric.png`
  - `docs/assets/screenshots/settings-display.png`
  - `docs/assets/screenshots/settings-appearance.png`
- 实际 Demo GIF 尚未存在，README 当前使用计划路径：`docs/assets/demo/notchmuse-beta-demo.gif`。
- README 构建命令仍使用 `./scripts/build_release.sh 0.3.0-beta 3`，最终 build number 需要 PM / release owner 确认。
- CHANGELOG 中 `0.2.1 - In Development` 和 `0.2 - In Development` 仍保留历史状态；是否整理为正式历史版本需要 PM 决策。
- 本线程未验证 DMG、checksum、GitHub tag、GitHub Release 上传状态。

## Recommended Actions

- README Final:
  - 当前 README 可作为 GitHub Open Source Beta 文档基础发布。
  - 等截图/GIF 准备好后，只替换 README 中对应路径，不需要再改结构。
- Screenshot 清单:
  - 必需：Status Bar Right，显示 Spotify 正在播放和菜单栏歌词。
  - 必需：Notch Mode Song + Lyric，展示核心 notch 场景。
  - 必需：Settings Display，展示模式、位置、宽度和显示屏设置。
  - 可选：Settings Appearance，展示颜色、字号、动画速度、透明度。
  - 暂不建议首批展示 Left layout，除非 PM 想主动解释 Accessibility 权限。
- Demo GIF 方案:
  - 文件路径：`docs/assets/demo/notchmuse-beta-demo.gif`。
  - 时长：8-12 秒。
  - 流程：Spotify playing -> NotchMuse lyric appears -> switch Notch style or width -> lyric updates smoothly。
  - 使用干净桌面，隐藏私人账号信息和无关菜单栏图标。
  - 默认用英文 UI，除非 PM 决定做双语素材。
- Installation:
  - 当前 README 的 unsigned 安装说明可以保留。
  - Release body 中也应重复提醒 unsigned beta 的 macOS 打开方式，减少用户下载后困惑。
- Known Issues:
  - 当前 README 已覆盖 unsigned beta、第三方歌词覆盖率、line-level timing、Left layout Accessibility、第三方版权归属。
  - 首发无需扩展更多 Known Issues，避免制造不必要噪音。
- Release Notes 草稿，可直接贴 GitHub:

```markdown
## NotchMuse 0.3.0 Beta

NotchMuse is a lightweight native macOS lyrics companion for Spotify. This GitHub Open Source Beta focuses on synchronized lyrics in the menu bar and notch area for Apple Silicon Macs.

### Highlights

- Status Bar and Notch Mode lyrics display.
- Lyric Only, Song + Lyric, and Expanded Notch styles.
- Adjustable lyrics width, font size, color, animation speed, and opacity.
- English and Simplified Chinese interface.
- Lyrics matching through LRCLIB, NetEase Cloud Music, LRCMux, QQ Music, Kugou Music, and Soda Music.
- Local settings storage with no NotchMuse account, telemetry, or NotchMuse-owned server.

### Installation Notes

- Download `NotchMuse.dmg`, open it, and drag `NotchMuse.app` to Applications.
- This beta is unsigned. macOS may block the first launch.
- To open it, Control-click `NotchMuse.app`, choose `Open`, then confirm.
- If macOS still blocks the app, use `System Settings > Privacy & Security > Open Anyway`.
- Allow Spotify Automation permission when prompted.

### Requirements

- macOS 14.0 or later.
- Apple Silicon Mac.
- Spotify desktop app.

### Known Issues

- Intel Mac is not supported in this beta.
- Lyrics coverage and stability depend on third-party lyrics services.
- Timing is primarily line-level and may not include word-level timing.
- Left Status Bar layout requires Accessibility permission and may be affected by menu bar management tools.

### Distribution

Developer ID signing and Apple notarization are planned for a future Distribution Phase.
```

## Need PM Decision

- 最终 GitHub tag 是否确定为 `v0.3.0-beta`。
- 最终 build number 是否继续使用 `3`。
- 首发截图是否只用英文 UI。
- 是否需要首发 Demo GIF；如果时间紧，README 当前可以先保留 planned asset 路径，等素材补齐后再替换。
- 是否展示 Left layout 截图。
- CHANGELOG 中 `0.2.1 - In Development` 和 `0.2 - In Development` 是否改为正式历史版本，还是保留内部里程碑状态。
