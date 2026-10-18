<p align="center"><a href="README.md">English</a> | 简体中文</p>

<h1 align="center">NotchMuse v0.8.1</h1>

<p align="center"><img src="website/assets/media/notch-poster.webp" alt="NotchMuse 在 macOS 上实际显示的浮层歌词" width="1080"></p>

<p align="center">把同步歌词放在 Mac 菜单栏、刘海旁，或屏幕边缘。</p>

<p align="center">macOS 14+ · Apple Silicon · Spotify · Apple Music · 网易云音乐 · QQ 音乐 · 汽水音乐</p>

<p align="center"><a href="https://notchmuse.com"><strong>官网下载</strong></a> · <a href="https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1"><strong>GitHub Release</strong></a> · <a href="https://github.com/Xiye88/NotchMuse/issues"><strong>报告问题</strong></a></p>

## 菜单栏歌词

![NotchMuse 在 macOS 菜单栏中实际播放歌词](docs/assets/demos/github/status-bar-demo.gif)

同步歌词自然融入 Mac 菜单栏，显示位置可以调整。

## 刘海模式

![NotchMuse 浮层歌词在屏幕顶部和 Dock 上方显示](docs/assets/demos/github/notch-demo.gif)

让歌词靠近刘海，或将浮层移到 Dock 上方。本次录屏展示顶部和 Dock 位置。

## 定制你的歌词

![NotchMuse 实际播放中切换歌词颜色、渐变和背景](docs/assets/demos/github/appearance-demo.gif)

选择适合桌面的纯色、渐变色和歌词背景。

![NotchMuse v0.8.0 外观设置](docs/assets/screenshots/appearance-settings.png)

<details>
<summary>显示设置</summary>

![NotchMuse v0.8.0 显示设置](docs/assets/screenshots/display-settings.png)

</details>

## 支持的播放器

Spotify · Apple Music · 网易云音乐 · QQ 音乐 · 汽水音乐。可以手动选择，也可以让自动检测跟随当前正在播放的应用。

## 核心功能

| 歌词位置 | 个性化 | 日常使用 |
| --- | --- | --- |
| 菜单栏、刘海歌词 | 纯色与渐变色 | 自动检测播放器 |
| 屏幕左侧或右侧 | 背景、透明度、宽度 | 简体中文与 English |
| Dock 上方歌词 | 外观预设 | 应用内更新设置 |
| 自定义宽度与位置 | 跟随系统、浅色与深色外观 | 开机自动启动；Dock 与菜单栏图标控制 |

网易云、QQ 音乐和汽水音乐使用随应用打包的 MediaRemote bridge，无需 Homebrew 或额外安装 helper。macOS 或播放器升级后可能需要兼容性更新。

## 三步开始

1. 从[官网](https://notchmuse.com)下载 DMG，打开后将应用拖入“应用程序”。
2. 用任一支持的桌面播放器播放歌曲；Spotify 或 Apple Music 请求自动化权限时请允许。
3. 打开 NotchMuse，保留“自动检测”，在设置中选择歌词位置。

## 安装与安全提示

NotchMuse 通过官网和 GitHub 直接分发，目前尚未配置 Apple Developer ID 签名与公证。因此 macOS 首次打开时可能出现安全提示。这属于分发签名状态，与版本状态无关。

如果系统拦截，请打开 **系统设置 → 隐私与安全性 → 仍要打开**，按提示认证后再次启动。安装和权限问题见[使用支持](docs/community/SUPPORT.md)。不要通过关闭 Gatekeeper 或移除 quarantine 强制运行。见 [Apple“仍要打开”指引](https://support.apple.com/zh-cn/102445)。本次仅为 ad-hoc 签名，未使用 Developer ID，也未通过公证；尚未完成独立干净 Mac 首次安装验证。目前不支持 Intel Mac。

## 更新至 v0.8.1

**本次需要手动安装。** 下载 [v0.8.1 / Build61](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/NotchMuse.dmg)，对照 [SHA256SUMS](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/SHA256SUMS) 校验，退出旧正式版，再替换“应用程序”中的 NotchMuse。需要回滚时请将旧 App 和偏好设置一并备份；[v0.8.0](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.0) 仍然保留。不要用正式包覆盖 Preview。

Sparkle 正式 feed 暂时保留 Build47，应用内“检查更新”**不会提供 Build61**。本包尚未完成隔离环境中的真实更新安装及失败恢复验证，仅有签名校验不足以启用自动更新。

### 本次改进

Spotify 身份补全和联合歌手识别、录音与版本保护、请求恢复及缓存防护、网易云原生身份验证，以及明确区分“检索中 / 超时 / 无歌词”的界面状态。无需 Spotify Premium 或用户 API Key。歌词仍取决于第三方覆盖率。见[中文发布说明](docs/releases/v0.8.1/RELEASE_NOTES.zh-CN.md)。

## 常见问题

**某首歌没有歌词？** 歌词取决于第三方歌词来源覆盖率；支持播放器不代表每首歌都能匹配。

**会上传音频吗？** 不会。应用读取播放元数据，可能将歌名、歌手、专辑和时长发送给歌词来源用于匹配；不收集遥测，也不要求注册账号。

**菜单栏图标不见了？** 其他菜单栏工具可能将它隐藏。NotchMuse 不管理其他应用的菜单栏图标。

## 支持 NotchMuse

<details>
<summary>查看赞助方式</summary>

应用内提供 Support 页面，也可以使用以下二维码：

| 微信支付 | USDT · EVM | USDT · TRON |
| --- | --- | --- |
| <img src="MenuBarLyrics/Resources/WeChatSupport.jpg" alt="微信支付二维码" width="150"> | <img src="docs/support/usdt-evm.png" alt="USDT EVM 二维码" width="150"> | <img src="docs/support/usdt-trc20.png" alt="USDT TRON 二维码" width="150"> |

EVM 地址支持 Ethereum、BNB Smart Chain (BEP20)、Arbitrum 和 Optimism；TRON 使用独立 TRC20 地址。转账前请核对网络，并且只发送 USDT。[支持者名单](docs/support/supporters.json)仅展示已同意公开的信息。

</details>

## 许可与反馈

NotchMuse 使用 MIT License；内置第三方组件见[第三方声明](THIRD_PARTY_NOTICES.md)。使用问题请看[支持文档](docs/community/SUPPORT.md)和[反馈指南](docs/community/FEEDBACK.md)，或直接[提交 Issue](https://github.com/Xiye88/NotchMuse/issues)。架构与构建文档见 [docs/README.md](docs/README.md)。
