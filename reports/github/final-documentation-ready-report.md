# Final Documentation Ready Report

Task: 06_DOCS GitHub Release Visual Package

Status: Completed

Priority: P0

## Findings

- 已完成 GitHub Release Visual Package 的最低截图要求。
- README 已引用 3 张实际 PNG：
  - Status Bar Mode: `docs/assets/screenshots/status-bar-mode.png`
  - Notch Mode: `docs/assets/screenshots/notch-mode-crop.png`
  - Settings: `docs/assets/screenshots/settings-window.png`
- 三张截图均来自当前本机 `dist.noindex/NotchMuse.app` 运行状态，没有修改 Swift 代码或核心 App 逻辑。
- Notch Mode 和 Settings 使用 window-level screenshot，画面较干净。
- Status Bar Mode 使用 Status Bar overlay window 截图，能展示菜单栏歌词形态。
- README 已保留 Demo GIF plan，并明确 Demo GIF 在 beta freeze 阶段可因成本高延期。
- README 仍保持面向 GitHub 用户的英文说明，Installation 已包含 unsigned macOS security warning、Control-click `Open`、`Open Anyway`。

## Problems Found

- Demo GIF 尚未生成；当前按“可选，成本高则延期”处理。
- Status Bar Mode 截图受歌词滚动窗口宽度限制，只展示当前滚动片段，不是完整长句。
- 截图内容来自当前 Spotify 播放状态，歌曲名/歌词会随现场播放变化；如果 PM 希望品牌更统一，需要指定曲目后重截。
- 当前截图没有额外做营销排版或设备外框，只是最小可用 release screenshots。

## Recommended Actions

- 当前 3 张截图可用于 v0.3.0-beta Release Candidate Freeze。
- GitHub Release 页面可直接使用 README 中已有图片引用。
- Demo GIF 建议延期到 beta 发布后或 Distribution Phase：
  - 路径：`docs/assets/notchmuse-demo.gif`
  - 时长：10-15 秒
  - 内容：Spotify playback -> live lyrics -> switch display mode -> open Settings
- 如果发布前还有 10 分钟视觉 polish 时间，优先重截 Status Bar Mode，等待短歌词或较完整滚动位置再抓。
- 不建议为本次 freeze 增加设计包装、视频剪辑或新视觉系统；最低 release package 已满足。

## Need PM Decision

- 是否接受当前 3 张最小截图作为 v0.3.0-beta GitHub Release visual package。
- 是否要求指定一首固定歌曲重截截图。
- Demo GIF 是否确认延期到 beta 之后。
- 是否需要在 Release Notes 中显式写明 “Demo GIF deferred”。
