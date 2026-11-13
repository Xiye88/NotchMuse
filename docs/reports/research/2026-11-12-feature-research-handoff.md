# NotchMuse 调研与开发交接摘要

日期：2026-11-12 至 2026-11-13
用途：交给 GPT PM 判断下一阶段是否继续开发。

## 本轮目标

核实 Preview 自动更新，评估 Apple Translation，完成已有歌词译文双语 MVP，验证 RSS Podcast Transcript 路线，并确认是否存在此前提到的真正播客字幕项目。

## 已完成

- Preview 自动更新：启动静默检查、独立自动下载安装开关、默认开启、用户关闭持久化、Sparkle 每86400秒调度。Preview71→72 已实测自动下载、安装和重启。正式版 v0.8.2/Build70 未改变。
- Apple Translation PoC：Translation.framework 可编译，en→zh-Hans 语言对受支持，但当前 Mac 模型未安装且不可请求下载，未完成速度/质量/离线实测。暂不接入，结论 C（证据不足）。
- 双语歌词 MVP：网易同响应读取 tlyric；按译文 offset 与时间戳做450ms内双向唯一对齐；原文时间轴、身份、Provider和缓存规则不变。原文上、中文下；仅刘海/自由浮层显示；菜单栏保持单行；新增默认关闭的双语开关。
- Podcast Transcript：AlgerMusicPlayer 没有独立 Transcript/ASR 引擎。Podnews RSS 已实测存在 podcast:transcript VTT，字幕文件可访问并含有效时间戳。
- GitHub About、发布规范和跨渠道一致性检查已在前一轮完成；本轮不发布 App。

## 测试证据

- `scripts/test_bilingual_lyrics.sh`：先失败8项，修复后23项通过。
- `swift build --package-path MenuBarLyrics -c release`：双语候选编译通过。
- Preview 更新策略、生命周期和打包检查：此前已通过；完整 XCTest 仍受本机缺少 XCTest 模块限制。
- Podcast 实例：`https://podnews.net/rss`，第一条带 VTT Transcript；GUID、音频 enclosure 和字幕 URL 来自同一 RSS item。

## 未完成

- Apple Translation 模型下载授权、三轮冷/热翻译、CPU/RSS、质量和断网测试。
- 双语 Preview 的实际视觉验收和真实网易译文覆盖测试。
- Podcast Swift RSS/VTT/SRT 解析、真实播放同步、动态广告偏移和 Spotify/网易云节目身份绑定。
- 尚未找到 PO 所说的另一个真实 Transcript 项目；如不是 AlgerMusicPlayer，需要补充项目名称或链接。

## 当前状态

- 双语代码和三个报告已保存在本地提交 `ba5f005`。
- 本轮没有推送双语代码，没有修改 Stable、Release、Tag、正式 Sparkle 或官网。
- 报告正文：[2026-11-12-feature-research.md](2026-11-12-feature-research.md)
- 三个 Track 报告：
  - [APPLE_TRANSLATION_POC_REPORT.md](APPLE_TRANSLATION_POC_REPORT.md)
  - [BILINGUAL_LYRICS_MVP_REPORT.md](BILINGUAL_LYRICS_MVP_REPORT.md)
  - [PODCAST_TRANSCRIPT_FEASIBILITY_REPORT.md](PODCAST_TRANSCRIPT_FEASIBILITY_REPORT.md)

## PM 建议

1. 先做双语 MVP 的 Preview 视觉验收，再决定是否保留当前数据结构。
2. Apple Translation 只有在用户完成系统模型下载后再继续 PoC；没有必要现在接入云翻译。
3. Podcast 先补真实项目名称/链接；RSS Transcript 可做单节目技术样本，但暂不做 ASR 或批量抓取。
4. 自动更新仍需补长驻、断网、坏包和失败安装场景后，才考虑正式版升级。
