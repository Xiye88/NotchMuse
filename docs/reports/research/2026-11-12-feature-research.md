# NotchMuse统一技术调研 — 2026-11-12

本轮只读调查与报告，不修改功能、打包、发布或重复歌词验收。事实以当前本地046ca63、远端main b5fcbe2、项目证据及本对话PO原话为准。工时为单工程师净开发估算，不含外部服务授权/PO排期。

## 1. 自动更新：实现、通过项、缺口

### 文件与机制
- `MenuBarLyrics/Sources/MenuBarLyrics/App/UpdateController.swift`：startIfStable启动SPUUpdater后，同runloop调用checkForUpdatesInBackground；前提自动检查开启且没有session。原生后台检查不把无新版当用户请求弹窗。手动checkForUpdates保留结果与网络重试反馈。
- `App/UpdatePolicy.swift`：区分启动检查/手动检查/准备完成提示。仅startupCheck且checksEnabled、automaticInstall均为true时允许立即安装；其它准备完成结果留下一次提示标记。
- `UI/SettingsWindowController.swift`：保留自动检查开关，增加独立自动下载安装开关；绑定Sparkle属性，不在每次启动强写true。
- `App/AppDelegate.swift`已经调用startIfStable，本次未修改；`App/UpdateFeedback.swift`亦沿用而未修改。
- 配套`Resources/en.lproj/Localizable.strings`及zh-Hans、`scripts/build_app.sh`设置Preview默认值；Preview启用loopback时SUAutomaticallyUpdate/SUAllowsAutomaticUpdates=true，SUScheduledCheckInterval=86400。Stable打包默认值仍未提升，正式70安装包更未改变。
- 定时由Sparkle自身timer触发，无新增自建轮询器。86400是正常调度，不保证睡眠/离线时精确在墙钟24小时请求；已下载待安装更新可能进入Sparkle不同调度分支，不能只看该常量承诺所有状态每天提醒。

### 四种用户流程
1. 自动检查ON、自动安装ON、启动发现新版：取feed→选择可用新版→后台下载→验证签名/准备安装→willInstallUpdateOnQuit经policy判定→调用immediateInstallationBlock并returnYES→原生安装并重启。可能因系统授权等要求交互，不能保证所有机器无感。71→72实测如此。
2. 自动检查ON、自动安装OFF：后台发现新版由Sparkle普通更新界面提示，可稍后/跳过/确认安装；也可手动检查。新开关不是屏蔽提醒开关。
3. 自动检查OFF：启动及定时不自动发现；手动检查仍可用。仅自动安装ON但检查OFF不会自动找新版，UI已说明。
4. 已运行一段时间、启动cycle已结束后发现新版：后台准备包后policy不调用立即重启；完成cycle后一次checkForUpdates恢复已准备包的原生安装提示。关闭自动更新不等于撤销已排队安装，退出时仍可能应用。此流程代码与策略测试覆盖，完整长驻UI尚未实测。启动下载很慢仍算启动cycle，不存在固定“启动前几秒”截止；若要避免下载数分钟后自动重启，须后续明确时机限制。

### 失败、偏好与状态
后台无新版/网络失败默认安静；手动网络失败有重试。校验/安装错误交由Sparkle，不绕过验证；本代码不能证明每种安装失败都自动恢复成功。Preview交付脚本确实演练过一次启动验证失败→恢复69；这与Sparkle安装器内部恢复是不同测试。签名错误应被原生拒绝，但本候选尚无坏包安装实测。

Sparkle通过同bundleID的UserDefaults保存SUEnableAutomaticChecks/SUAutomaticallyUpdate，升级替换App不会主动清偏好。默认读取Info配置、明确false覆盖默认；跨实例偏好测试通过。Preview与Stable偏好域分离。改bundleID/删除设置/未来错误迁移不在此保证内。

本地功能提交046ca63，远端main实查b5fcbe2：规范、状态文档已同步，自动更新Swift/UI/打包改动仍只在本地。已安装0.8.3 Preview72是相同runtime、递增Build后重新签名的测试fixture，并非正式版。公开0.8.2/70已有旧版通知更新链路，但没有本轮新自动策略。

通过证据：36策略/原生偏好/ObjC委托检查、3组打包配置、23提示检查、生命周期成功/失败回滚保护；App编译/签名/包自测；无新版启动无弹窗；UI两开关默认ON；71→72真实签名本地源自动安装重启；真实日志delay/interval86400。
未完成：实际持续24小时及睡眠唤醒；长驻prepared包提醒完整UI；断网UI、损坏签名/安装失败矩阵；完整XCTest（CLT缺XCTest）。Preview仅有loopback feed/enclosure检查，签前人工核验实际包身份；共享正式公钥不是独立Preview信任边界，notes/redirect等尚需收口。不能据此宣称所有跨渠道/失败场景已通过。

用户价值高；技术可行性已证明；剩余资格验证中等难度，约2–4工作日，视失败修复增加。MVP为上述行为且失败/长驻场景闭环。值得优先收尾，不直接提升正式版。

## 2. 刘海自由拖动

真实需求恢复：此前PO要求可拖动的歌词框、保存位置、锁定/穿透、横竖排；不能把“刘海”理解为可移动硬件刘海。本轮最终结构虽列此项，但并非新开发指令。

当前已实现：OverlayLyricsWindow.free/freeLane与FreeLyricsInteraction；mouseDragged负责拖动，FreeLyricsAnchor按可移动区域比例存x/y及屏幕ID；横竖排独立偏好，切屏或屏幕消失回退，边界限制可见范围；NSPanel渲染、锁定与独立解锁控件、穿透。0.8.2发布说明已有该功能。

产品方案：保留“自由定位”显示模式，双语时在同一框内上下排；固定刘海模式和单行菜单栏保持原体验。无需重建拖动系统。现有MVP已满足自由放置，价值高，新增开发优先级低；双语增高后的边界恢复/竖排可读性需做小范围适配（1–2日估算），不是再做一次自由拖动。风险为多屏、尺寸变化、穿透后控制可达；不重复已接受的原有歌词验收。

## 3. 歌词自动翻译

### 真实产品范围
PO原话是把英文歌词翻成中文，用在“可拖拽的歌词框”或“刘海/标签栏歌词框”，明确不放单行菜单栏。后者术语应结合现有notch浮层解释，不能静默扩展到菜单栏或所有屏幕。重点是双语阅读，尚未授权实时音频翻译、全语种大模型或收费系统。

### 当前能力
NetEaseLyricSource.request请求tv/ytv等，但LyricResponse只解码code/yrc/lrc，未读取tlyric；LyricLine只有原文text/time/endTime/segments，TimedLyricDocument也无译文映射。LyricsClient返回原文数组、管理候选身份与内存缓存；当前没有完整原文+译文同步显示能力。其它Provider也未发现统一译文通道。OpenCC字形转换不能当英中语义翻译。

### 低成本顺序
A. 先复用选中同一网易歌曲ID响应中的tlyric/可用译文轨。原文仍是唯一播放时间基准；按时间戳、offset和邻近容差对齐，保留未匹配/合并行，不按数组下标强配，不为译文伪造逐词时间。无译文时仍正常显示原文，绝不拉另一录音译文凑数。该能力提升阅读体验，不提高原文歌曲匹配覆盖率。
B. 无译文且用户主动启用机器翻译，优先评估Apple Translation本地能力：先查系统/语言对支持与模型是否安装，必要时系统征求语言下载许可。当前最低macOS14，不能假定所有安装用户可用；用可用性分支，不为翻译提高全App系统门槛。AppKit可用小SwiftUI会话桥接，需小样本技术验证。官方文档说明模型下载/语言支持，不等同于保证所有语言歌词质量。
C. 仅当设备覆盖/质量不足，再考虑一个合规云翻译供应商。不先搭多模型路由或GPU服务器。价格未选型，不能编造每首固定价格；按首次去重字符/请求量计费，缓存命中不重复请求。公式：新增待译字符量÷计费单位×供应商单价，加网关运维；必须对照最终官方价格/条款再预算。翻译歌词不能补没有原文的歌曲。

### 模块和缓存
扩展候选附属文本/TranslatedLyricsDocument（sourceLanguage、targetLanguage、来源、正文hash、lineID→译文）；Provider读取已有译文；轻量TranslationService处理可选机翻；TranslationCache做受许可约束的有界持久缓存；UI双语layout；Settings增加“关闭/已有译文优先/允许机器翻译”和目标语言。首期目标英→简中，独立于界面语言，并保留以后语言列表的接口而不实现全语言。
缓存key包含已确认录音/ProviderID、原文规范hash、目标语言、引擎/版本；切歌取消与requestID/generation校验沿用，避免晚到译文串歌；同key合并在途请求；不逐帧/逐词调用API。长曲分段、整首批量翻译保留lineID，不让模型重写行顺序；失败保留原文，允许用户重试。缓存期限和可否跨用户共享须依据来源授权，初期仅本机，避免擅自共享歌词全文。

会员可行但目前未见账户/订阅/权益校验模块。建议已有来源译文先基础提供；未来会员提供有配额的云翻译和额外语言；不要承诺无限翻译，也不要在客户端内置云API密钥。需要服务端密钥/额度/限流和权益模块时才增加网关。开源代码许可不涵盖歌词及译文内容的商业再使用。

价值高；现有译文MVP中等，约4–7日；本地机翻再加3–5日验证和适配；云端会员属于另一阶段，不能算一个小开关。主要风险对齐、翻译质量、系统覆盖、缓存/商业许可与费用。建议先做A，B小样本再决定，C暂缓。

## 4. 播客字幕：项目定位与可复用性

检索本地Documents/Downloads/worktrees的项目文件与交接、当前研究资料，查看Codex近期/历史两页、ChatGPT近期历史及“介绍 AlgerMusicPlayer”原始讨论，并检查Xiye88公开仓库名称/说明关键词。没有把字幕长图/YouTube下载素材当成播客软件。

准确确认的历史项目为 **algerkong/AlgerMusicPlayer**：https://github.com/algerkong/AlgerMusicPlayer ，本对话PO曾明确提供该仓库。固定调查SHA f57204d4205769a4457f5975796a35e41785f1d8。本地保存的是源码调查证据而非已导入的Swift项目：`/Users/carlos/.codex/visualizations/2026/11/01/01a19656-f50b-7351-a74f-d08ebe5d0af3/alger-lyrics-comparison-20261109/`，重点SOURCES-PODCAST-ADDENDUM.md及source-podcast-evidence/manifest.json。

**尚不能确认它就是PO此次所说的“含Transcript的那个项目”。** 其固定源码恰好没有独立Transcript实现。若另有项目，缺少准确名称或GitHub链接，当前访问范围未找到，不能替它作许可证/模型/格式分析。

| 问题 | 已确认Alger源码结论 |
|---|---|
| 如何获取播客 | src/renderer/api/podcast.ts请求网易/dj/detail、/dj/program；podcastUtils.ts将program.mainSong.id映射播放器ID，简介不是全文稿 |
| RSS还是ASR | 两者均未见独立链路；播放复用网易mainSong.id通用歌词接口 |
| 字幕格式 | 通用歌词LRC/YRC；未见播客专用SRT/VTT/transcript解析，不宣称每个节目有词 |
| 时间同步 | 若通用接口有带时间歌词，沿通用播放器时钟；不是从description生成时间戳 |
| 多语言 | UI语言与节目内容语言不等于多语言转录；已有tlyric也非通用播客翻译 |
| 本地/云AI | 未发现播客转录模型调用，不存在据此可复用的Whisper/云ASR模块 |
| Key/服务器/付费 | 依赖网易第三方API网关/服务可用性，部分内容可能受登录限制；未发现ASR API Key配置，不代表平台数据无使用限制 |
| 可复用 | 节目/电台ID分离、元数据映射、已有译文对齐思路；没有可直接搬的播客字幕引擎 |
| Swift迁移 | Vue/TS/Electron不能直接链接进Swift；可独立实现小数据模型，代价主要在外部播放器节目身份/时间同步，而非文字控件 |
| 许可证 | 固定SHA LICENSE实际读取为MIT，复制实质代码需保留copyright/license；README并存学习/非商业说明，商业复制前需厘清。接口/节目音频/字幕权利和依赖许可独立核验。本轮不复制代码 |

若确认另一个真实Transcript项目，再逐文件检查RSS解析、ASR调用、格式和许可证。一般候选路线仅供后续方案：发布者RSS的podcast:transcript→读取带时间VTT/SRT→绑定GUID/enclosure/duration和外部播放进度。纯文本仅阅读，不能假造同步。动态广告/不同剪辑会使时间轴错位。RSS不是任意Spotify节目自动可得，外部播放器通常也不给完整RSS/GUID，需先证明一节目可准确绑定。Podcast Namespace规范支持Transcript引用，并不保证每个节目发布它。

价值中等且取决于真实字幕需求；已有Transcript MVP可行但中高难，项目和播放器来源明确后约1–2周小验证；全量ASR成本/权限/音频访问和同步复杂度高，暂不排期。没有原项目链接前不承诺代码复用或开发工期。

## 5. 优先级

1. P0收尾自动更新未完成矩阵及Preview隔离，完成下一版本资格验证；不直接公开发布。
2. P1已有来源译文＋双语显示：符合明确PO需求，低运行成本，复用自由定位框。
3. 自由拖动已存在，仅为双语布局做必要适配，不再另立重建项目。
4. P2本地机器翻译小验证；未证明需求/设备覆盖前不上会员云计费。
5. 播客先定位原项目与真实播放入口，再做单节目Transcript可得性验证；云ASR及大规模收录暂缓。

## 6. 下一阶段建议（非执行授权）

先花2–4日补自动更新失败、断网、长驻、包身份测试并审查启动慢下载导致晚重启的边界；之后用2–3个经确认已有译文/无译文/行不齐的固定文本夹具做双语设计验证，不重复大歌曲测试。A方案确认后实现来源译文MVP；同时只需PO补原播客项目名称或链接即可继续定向调查，无需提供账号密钥。当前停止在报告，不开新功能编码。

来源：本地代码与preview-verification.json；既有Alger固定SHA补查；Apple Translation官方文档 https://developer.apple.com/documentation/translation/translating-text-within-your-app ；Sparkle https://sparkle-project.org/documentation/customization/ 及SPUUpdaterDelegate文档；Podcast Namespace https://github.com/Podcastindex-org/podcast-namespace/blob/main/docs/tags/transcript.md 。本轮外部文档抓取部分失败，不据失败页作额外事实推断。
