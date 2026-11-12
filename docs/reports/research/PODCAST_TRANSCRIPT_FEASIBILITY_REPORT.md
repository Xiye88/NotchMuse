# Podcast Transcript Feasibility — 2026-11-12

## 已完成

重新检查了此前资料、工作区、历史聊天索引和 AlgerMusicPlayer 固定源码调查。能准确确认的项目仍是 `algerkong/AlgerMusicPlayer`，固定 SHA `f57204d4205769a4457f5975796a35e41785f1d8`。它有网易播客目录、节目元数据和通用 mainSong 歌词复用，但没有独立 RSS Transcript、SRT/VTT 解析、Whisper 或云端 ASR 链路。不能把它当作已有完整播客字幕项目。

本轮没有找到另一个可确认名称和链接的 Product Owner Transcript 项目。若所指项目不是 AlgerMusicPlayer，当前缺少准确名称或 GitHub 地址，不能继续做代码复制、许可证或依赖判断。

## RSS Transcript 独立验证

选择公开 `Podnews Daily` RSS：`https://podnews.net/rss`。实测第一条带字幕节目：

- 节目标题：`More fake shows on the way, as Meta’s Muse gets into podcasting`
- RSS item GUID：`https://podnews.net/update/fake-shows-muse-podcasting`
- 音频 enclosure：`https://op3.dev/e,pg=9b024349-ccf0-5f69-a609-6b82873eab3c/podnews.net/audio/podnews261111.mp3`
- `<podcast:transcript>`：`https://podnews.net/audio/podnews261111.mp3.vtt`
- 类型：`text/vtt`
- 字幕文件 HTTP 成功读取，7293 bytes，开头为 `WEBVTT`
- 第一条时间轴：`00:00:00.500 --> 00:00:04.330`

这证明 RSS Transcript 路线存在真实可访问样本，且至少支持 VTT。Podcasting 2.0 Transcript 规范和公开实践也涉及 VTT、SRT 等格式；具体节目格式由发布者决定，不能假定所有 RSS 都有字幕。

## 如何迁移到 NotchMuse

MVP 可以是独立的 PodcastTranscriptSource：解析 RSS item 的 GUID、enclosure URL/duration、podcast:transcript URL/type；下载 VTT/SRT；解析 cue start/end/text；以播放进度选择当前 cue。需要节目身份绑定时，优先使用 RSS GUID + enclosure URL + 时长，不能只用标题。若外部播放器只提供标题/艺术家而没有节目 GUID 或 enclosure，无法可靠绑定。

同步仍有风险：动态广告、地区插播、剪辑版本、重新上传音频和播放器进度偏差都会使 RSS 字幕时间轴错位。应显示来源和允许有限人工偏移；不能把节目 description 或 show notes 当作有时间戳字幕。

Spotify、网易云等外部播放器通常不会把 RSS GUID、enclosure URL 和 transcript URL 全部暴露给 NotchMuse。仅靠当前曲目标题无法证明对应同一节目，因此外部播放器自动接入应作为后续身份研究，不进入 MVP 承诺。

## 测试状态

**通过：** 公开 RSS 存在 transcript 声明；字幕 URL 可访问；类型为 VTT；文件含有效时间戳；GUID、音频 enclosure 与字幕链接能从同一 RSS item 关联。

**未测试：** Swift RSS/VTT/SRT 实现；真实音频下载/播放进度同步；动态广告偏移；Spotify/网易云节目身份暴露；多语言字幕；字幕文件授权条款；大规模节目覆盖。

**不做：** Whisper、本地/云端 ASR、付费 API、GPU 服务、批量抓取和会员系统。

## 风险、难度与建议

用户价值取决于节目和播放器身份，技术可行性中等。单节目 RSS 字幕 MVP 约 1–2 周，包括 RSS、VTT/SRT、身份模型、时间轴显示和偏移验证；外部播放器自动绑定会显著增加难度。主要风险是节目来源许可、身份不完整和广告时间轴漂移。

建议先保留为技术候选：等 Product Owner 提供真正的 Transcript 项目名称/链接，或先明确 NotchMuse 是否要支持“导入 RSS/节目”而不是从 Spotify/网易云自动猜节目。当前不进入大规模开发。
