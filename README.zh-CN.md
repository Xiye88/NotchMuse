<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

<h1 align="center">NotchMuse</h1>

<p align="center">
  <strong>一款原生 macOS 应用，把同步歌词放到菜单栏和刘海区域。</strong>
  <br>
  歌词在你需要的位置出现，不打断当前工作流。
</p>

<p align="center">
  <a href="https://github.com/Xiye88/NotchMuse/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/Xiye88/NotchMuse?include_prereleases&label=release"></a>
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&logoColor=white">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/Xiye88/NotchMuse"></a>
</p>

<p align="center">
  <a href="https://github.com/Xiye88/NotchMuse/releases/tag/v0.6.0"><strong>下载最新 beta</strong></a>
  ·
  <a href="https://github.com/Xiye88/NotchMuse/issues">报告问题</a>
</p>

<p align="center">
  macOS 14+ · Apple Silicon · Spotify 或 Apple Music
</p>

## 演示

### Status Bar Mode

使用其他应用时，歌词会保持显示在 macOS 菜单栏中。

[![Status Bar Mode demo](docs/assets/demos/notchmuse-status-bar-demo.gif)](docs/assets/demos/notchmuse-status-bar-demo.mp4)

### Notch Mode

歌曲信息和同步歌词会显示在 MacBook 刘海下方。

[![Notch Mode demo](docs/assets/demos/notchmuse-notch-mode-demo.gif)](docs/assets/demos/notchmuse-notch-mode-demo.mp4)

## 为什么是 NotchMuse？

- 工作时保持同步歌词可见，不需要切换到单独的歌词窗口。
- 可选择紧凑菜单栏显示，也可选择 MacBook 刘海布局。
- 原生、轻量，不需要 NotchMuse 账号，也不收集遥测数据。

## 功能

| **菜单栏歌词** | **刘海歌词** |
| --- | --- |
| 在菜单栏左侧或右侧保持显示 Spotify 或 Apple Music 同步歌词。 | 在刘海附近选择 Lyric Only、Song + Lyric 或 Expanded 布局。 |
| **重视隐私** | **适配你的工作区** |
| 不需要账号，不收集遥测数据，不上传音频。内置 English 和简体中文。 | 可选择内建或外接显示器，并调整宽度、颜色、字号、动画和透明度。 |

## 截图

### 完整 Mac 场景

Spotify 播放时，NotchMuse 可以在真实 macOS 工作区中保持可见。

![NotchMuse in a macOS workspace](docs/assets/screenshots/full-mac-context.png)

### Status Bar Mode

工作时，同步歌词保持显示在 macOS 菜单栏中。

![Status Bar Mode](docs/assets/screenshots/status-bar-mode.png)

### Notch Mode

歌词以紧凑、可扫视的布局显示在 MacBook 刘海附近。

![Notch Mode](docs/assets/screenshots/notch-mode-crop.png)

### Settings

选择显示模式，并调整宽度、颜色、字号、动画速度、透明度和开机启动行为。

![Settings](docs/assets/screenshots/settings-window.png)

## 快速开始

开始前请确认：NotchMuse 当前需要 macOS 14 或更高版本、Apple Silicon Mac，以及 Spotify 或 Apple Music。

1. 从 [GitHub Releases](https://github.com/Xiye88/NotchMuse/releases/tag/v0.6.0) 下载 `NotchMuse.dmg`。
2. 打开 DMG，把 `NotchMuse.app` 拖到 `Applications`。
3. 这个 beta 尚未 notarize：按住 Control 点击 `NotchMuse.app`，选择 `Open`，再确认 `Open`。
4. 打开 Spotify 或 Apple Music 并播放一首歌。
5. 在 Settings 中选择 Music Player，并在提示时允许 macOS Automation。
6. 在菜单栏里找到橙色音符图标。
7. 打开 Settings，选择 Status Bar Mode 或 Notch Mode。

## 安装

### 系统要求

- macOS 14.0 或更高版本
- Apple Silicon Mac
- Spotify macOS 桌面应用或 Apple Music

当前 beta 构建仅支持 `arm64`。Intel Mac 和 Universal Binary 支持计划在后续阶段处理。

1. 从 GitHub Releases 下载 `NotchMuse.dmg`。
2. 打开 DMG。
3. 把 `NotchMuse.app` 拖到 `Applications`。
4. 从 `Applications` 打开 NotchMuse。
5. 当 macOS 询问是否允许控制当前音乐播放器时，选择允许。

### Beta 签名说明

这个 GitHub beta 已进行 ad-hoc signing，但尚未使用 Apple Developer ID 签名或 notarize。macOS 首次启动时可能会要求你确认。

打开方式：

1. 在 Finder 中打开 `Applications`。
2. 按住 Control 点击 `NotchMuse.app`。
3. 选择 `Open`。
4. 再次确认 `Open`。

如果 macOS 仍然拦截，前往 `System Settings > Privacy & Security`，为 NotchMuse 选择 `Open Anyway`。

Developer ID signing 和 Apple notarization 已推迟到未来 Distribution Phase。

如果安装、Gatekeeper、音乐播放器 Automation permission 或歌词查询失败，请查看 [SUPPORT.md](SUPPORT.md)。

## 可选菜单栏设置

NotchMuse 不要求安装菜单栏整理工具。如果你的菜单栏已经很拥挤，可以选择 Ice、Thaw 或 Bartender 等工具，为 Status Bar Mode 腾出空间。

## 已知问题

- beta 尚未使用 Apple Developer ID 签名或 notarize，因此 macOS Gatekeeper 警告是预期行为。
- 歌词覆盖率依赖第三方 provider。
- 不保证逐字歌词；多数 provider 返回的是逐行时间轴。
- Left Status Bar mode 需要 Accessibility permission。
- 其他菜单栏管理工具可能隐藏 NotchMuse 图标。
- 当前 beta 不支持 Intel Mac。

## 路线图

- 当前 beta：Spotify 和 Apple Music 播放
- 后续：歌词质量、signed distribution 和更广泛的 Mac 兼容性

## 使用

1. 打开 Spotify 或 Apple Music 并播放一首歌。
2. 打开 NotchMuse。
3. 歌词会显示在菜单栏或刘海区域。
4. 使用菜单栏音符图标打开控制菜单。
5. 打开 Settings，更改显示模式、位置、颜色、宽度、字号、动画速度、透明度和启动行为。

如果菜单栏整理工具隐藏了 NotchMuse 图标，请展开隐藏的菜单栏项目，或重新打开 NotchMuse 让菜单回来。

## 权限

- Automation / Spotify 或 Apple Music：读取当前曲目、播放状态和播放位置。
- Accessibility：仅 Left Status Bar 布局需要，用于避开当前应用的菜单项。
- Network：为当前歌曲查询公开歌词 provider。

## 反馈

安装和使用问题请先查看 [SUPPORT.md](SUPPORT.md)。反馈请阅读 [FEEDBACK.md](FEEDBACK.md)，然后使用 [GitHub Issues](https://github.com/Xiye88/NotchMuse/issues)。可复现问题请选择 **Bug report**，具体使用场景或改进建议请选择 **Feature request**。

## 隐私

- 不需要 NotchMuse 账号。
- NotchMuse 不读取或上传 Spotify 或 Apple Music 音频。
- NotchMuse 不收集遥测数据、使用分析或个人资料。
- 曲名、artist、album 和时长可能会发送给第三方歌词 provider 用于匹配。
- 设置使用 `UserDefaults` 保存在本地。

## 开发者文档

架构、构建与测试、Lyrics Quality Benchmark、Evidence Gate、Matcher 设计和 Provider 分析统一收录在 [Developer Documentation](docs/README.md)。

## 许可证

NotchMuse 使用 MIT License 发布。第三方声明列在 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
