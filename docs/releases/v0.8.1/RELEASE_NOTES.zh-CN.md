# NotchMuse v0.8.1

Build61 · macOS14+ · Apple 芯片 · 手动安装。

[下载安装包](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/NotchMuse.dmg) · [SHA256SUMS](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/SHA256SUMS) · [English](RELEASE_NOTES.en.md)

## 相比 v0.8.0 Build47

- 使用 Spotify 公开歌曲身份和完整联合歌手信息，提高现有来源的正确歌词召回；该链路无需 Spotify Premium、开发者账号或用户 API Key。
- 按歌曲、歌手、录音版本和时间轴证据选择歌词，保护错歌、Live/Remix 等版本冲突，替代“最快非空结果”的做法。
- 规范多歌手元数据并保留来源信息；在保留版本保护的前提下恢复可靠候选。
- 网易云 Exact-ID 仅在新鲜的本地播放状态、队列和当前播放器身份一致时使用，恢复播放后重新授权。
- 保留歌词行/词时间信息，阻止切歌或切换播放器后旧请求覆盖当前结果。
- 界面区分搜索中、无歌词、超时和网络失败；正式配置关闭 Preview 诊断入口及 Shadow 服务。

## 要求与限制

macOS14+、Apple Silicon。保留 Spotify、Apple Music、网易云、QQ音乐及汽水音乐集成；部分播放器依赖私有 MediaRemote 行为，系统或播放器升级可能影响兼容性。

歌词可用性取决于第三方来源和录音信息，并非所有歌曲/版本都有歌词。慢网络下首次查询仍可能耗时数秒；工程候选命中率不等于人工歌词正确率。

本包为 **ad-hoc 签名，不是 Developer ID 签名，未经 Apple 公证**。本次发行不要求购买 Apple Developer；真实干净 Mac 首次安装验收仍待完成，不能将本地自测视为通过。

## 安装

仅从官方 GitHub Release 或 notchmuse.com 下载；执行 `shasum -a 256 NotchMuse.dmg`，与同一版本 `SHA256SUMS` 核对。打开 DMG，将 NotchMuse 拖入“应用程序”，推出镜像，再打开已安装 App。

若 macOS 提示无法验证开发者，仅在确认官方来源及校验一致后，前往 **系统设置 → 隐私与安全性 → 仍要打开**，再确认打开。不要关闭 Gatekeeper，也不要用终端删除隔离标记。若提示恶意软件或 App 损坏，应停止并核对下载，不强制运行。[Apple 官方说明](https://support.apple.com/en-us/102445)。

打开受支持播放器并播放音乐；Spotify／Apple Music 如请求自动化权限，由用户确认。菜单栏可进入设置和退出。尚未完成独立干净 Mac 的首次安装与权限验证，本说明不声称此项已通过。

## 升级与回滚

本次采用**手动下载安装方案**。现有 Build47 正式更新 feed 保持不变，不通过 Sparkle 推送 Build61。Build61 的更新包签名已用旧版公钥验证，但真实隔离47→61安装、重启和失败恢复尚未通过；签名验证不能替代完整更新验收。

手动升级前退出旧正式版，同时备份 App 和偏好设置；回滚时退出新版本，再恢复这两项。常规 Preview 维持独立，勿用正式包覆盖 Preview。保留公开 v0.8.0 下载用于回滚。
