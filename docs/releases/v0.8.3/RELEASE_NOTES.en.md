# NotchMuse v0.8.3

> English release notes appear first, followed by the full Chinese release notes below.
> 英文更新说明在前，完整中文更新说明附后。

---

## English

### Highlights

#### 1. Major Lyrics Matching & Stability Upgrade (Up to 90% Across All 4 Players)
In our 100-track multi-genre and multi-language benchmark (Mandopop classics, C-pop new releases, English pop/rock/hip-hop, and Japanese/Korean/French/Spanish tracks), synced lyrics hit rate improved dramatically over v0.8.2:
- **Apple Music**: `43% → 90%` (**+47%**)
- **Spotify**: `58% → 90%` (**+32%**)
- **NetEase Cloud Music (generic pipeline)**: `43% → 90%` (**+47%**)
- **Soda Music**: `43% → 90%` (**+47%**)

Key technical improvements:
- **Restored Kugou (word-by-word KRC) & QQ Music search pipelines**: Switched Kugou downloads to working mirrors with album metadata preserved, and prioritized reliable QQ Smartbox search.
- **Enhanced LRC (`<mm:ss.xxx>`) word-level timing**: Fixed raw inline timestamp numbers appearing in lyrics and upgraded them to smooth word-by-word highlighting.
- **Apple Music & cross-platform metadata matching**: Fixed Traditional/Simplified Chinese mismatches (such as 周杰倫/周杰伦, 髮如雪/发如雪), added bilingual/K-pop artist alias normalization (`JJ Lin`, `Jay Chou`, etc.), supported `(with ...)` duets, parenthetical/OST subtitles, numeral albums (`11月的萧邦` / `十一月的萧邦`), and unified cross-source corroboration across all supported players.
- **QQ Music empty-album matching**: Tracks played in QQ Music macOS without album metadata now match directly against QQ Music's own catalog.
- **Faster responses**: Stopped waiting on degraded supplemental sources once primary direct providers reach a validated match, and added bounded transient-error retry.

#### 2. Proactive Startup Update Checks & Auto-Download Control
- NotchMuse now checks for updates quietly on launch (without intrusive popups when already up to date).
- Added an independent **Auto-Install Updates** toggle in Settings, giving you full control while preserving your existing preferences.

#### 3. In-App Release Announcement Banner & UI Polish
- Added a lightweight, dismissible announcement banner at the top of Settings and an unread item at the top of the menu bar dropdown so you can view new release highlights in one click.
- Restored native macOS frosted-glass vibrancy (`NSVisualEffectView`) with a crisp `0.5pt` highlight border on the Notch overlay.
- Upgraded the Free Floating mode hover toolbar to a native `.behindWindow` frosted capsule pill and added soft readability shadows for transparent backgrounds.

#### 4. Feedback & Community
If you run into any bugs, missing lyrics, or sync issues, please let us know anytime:
- **GitHub Issues**: https://github.com/Xiye88/NotchMuse/issues
- **Email**: ztongxue3@gmail.com
- **WeChat User Group**: Scan the QR code at https://notchmuse.com/assets/wechat-group-qr.jpg to join the NotchMuse community.

![NotchMuse WeChat Group QR](https://notchmuse.com/assets/wechat-group-qr.jpg)

---

## 中文

### 本次更新亮点

#### 1. 歌词匹配率与稳定性大幅升级（4 大平台实测命中率均提升至 90%）
基于 100 首多风格、多语种曲目（涵盖经典老歌、华语流行/新歌、英文流行/摇滚/Hip-Hop 及日/韩/法/西小语种）的同集实网对比测试，较 v0.8.2 正式版提升显著：
- **Apple Music**：`43% → 90%`（**+47%**）
- **Spotify**：`58% → 90%`（**+32%**）
- **网易云音乐（通用多源路径）**：`43% → 90%`（**+47%**）
- **汽水音乐**：`43% → 90%`（**+47%**）

核心修复与优化：
- **恢复酷狗逐字 KRC 与 QQ 音乐主力词源**：修复酷狗下载链路并保留专辑元数据；QQ 音乐优先切换至高可用搜索链路，大幅降低超时与空结果。
- **支持 Enhanced LRC（`<mm:ss.xxx>`）逐字解析**：彻底修复部分歌曲歌词中出现莫名时间数字的问题，并同步升级为逐字高亮。
- **全面优化 Apple Music 与跨平台曲目匹配**：修复繁简转换误杀（如 `周杰倫`/`周杰伦`、`髮如雪`/`发如雪`），新增中英/韩文歌手别名归一（`JJ Lin`、`Jay Chou` 等），支持 `(with ...)` 合唱格式、括号副标题、影视 OST 标题、数字专辑名（如 `11月的萧邦` / `十一月的萧邦`），并在全平台统一双直连源交叉印证机制。
- **修复 QQ 音乐无专辑名匹配**：解决 QQ 音乐桌面端未上报专辑名时自家正版歌词无法命中的问题。
- **更快的响应速度**：主力直连源达成一致后立即返回，不再空等失效辅助源，并补充瞬态网络错误轻量重试。

#### 2. 启动自动检查更新 & 自动下载安装开关
- 打开 App 时自动在后台静默检查新版本，无更新时不打扰；
- 设置页新增独立的 **自动下载并安装更新** 开关，兼顾省心升级与自主控制。

#### 3. App 内版本通知栏位与界面细节打磨
- 设置页顶部与菜单栏顶部新增轻量可关闭的更新公告入口，一眼直达最新版本说明；
- 恢复刘海歌词窗的 macOS 原生毛玻璃通透质感与 `0.5pt` 极细高光描边；
- 自由浮层悬浮工具栏升级为 `.behindWindow` 原生毛玻璃胶囊，并为透明背景补齐柔和可读性阴影。

#### 4. 问题反馈与用户交流群
如果你在使用过程中遇到任何 Bug、缺词或同步问题，欢迎随时反馈：
- **GitHub Issues**：https://github.com/Xiye88/NotchMuse/issues
- **邮箱反馈**：ztongxue3@gmail.com
- **加入微信交流群**：扫描上方二维码入群，直接向开发者反馈问题或体验新版本。
