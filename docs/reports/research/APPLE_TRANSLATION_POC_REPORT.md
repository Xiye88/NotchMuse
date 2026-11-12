# Apple Translation PoC（macOS 26.5.2）

日期：2026-11-12  
结论：**C — 当前无法采纳为歌词翻译方案；模型未安装，性能、质量和离线能力证据不足。**

## 范围

这是独立PoC，未修改NotchMuse产品源码、UI、最低系统版本或系统网络设置，也未调用云端翻译API。PoC使用24句原创英文文本，分为：

- ordinary：8句普通表达
- slang_metaphor：8句俚语和隐喻
- long_complex：8句较长复杂句

目标语言对为 `en → zh-Hans`。代码与原始输入位于 `/private/tmp/notchmuse-apple-translation-poc/`。

## 环境和API

- macOS 26.5.2（Build 25F84），Apple arm64
- Swift 6.3.3，SDK目标 `arm64-apple-macosx26.4`
- SDK提供 `Translation.framework`
- 可编译API：`LanguageAvailability.status(from:to:)`、`TranslationSession.Configuration`、`.translationTask`、`TranslationSession(installedSource:target:preferredStrategy:)`、`isReady`、`translations(from:)`
- 编译成功，产物：`/private/tmp/notchmuse-apple-translation-poc/poc`

Apple API参考：

- <https://developer.apple.com/documentation/translation/languageavailability/status>
- <https://developer.apple.com/documentation/translation/translationsession/isready>
- <https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:)>
- <https://developer.apple.com/documentation/translation/translationsession/preparetranslation()>

## 实测结果

正常宿主权限下运行PoC耗时约 **0.296秒**，系统服务返回：

| 项目 | 结果 |
|---|---|
| source language status | `supported` |
| `en → zh-Hans` pair status | `supported` |
| `TranslationSession.canRequestDownloads` | `false` |
| `TranslationSession.isReady` | `false` |
| model available | `false` |
| translation rounds | 未运行 |
| UI响应 | 未测 |
| 离线翻译 | 未测 |

`supported`表示系统支持该语言对，但尚未完成本机安装；`installed`才表示可以直接翻译。PoC只创建了`installedSource`会话并检查就绪状态，没有调用`prepareTranslation()`，没有请求模型下载，也没有弹系统授权界面。

完整机器可读结果见 [`report.json`](/private/tmp/notchmuse-apple-translation-poc/report.json)。另有可交给CUA启动的独立SwiftUI授权探针：`/private/tmp/notchmuse-apple-translation-poc/TranslationProbeApp`；它使用`TranslationSession.Configuration`和`.translationTask`，只有点击按钮后才请求系统模型下载授权。受限运行环境中，第一次状态查询在20秒内无响应；正常宿主权限重试成功，因此这次受限超时被记录为运行环境现象，不能解释成翻译服务失败。

## 未完成和风险

由于模型未安装，三轮批量翻译没有执行，所以没有冷启动时间、暖批处理时间、CPU/RSS、翻译质量或长句/俚语错误率。CLI PoC也没有UI事件循环，无法代表歌词窗口的响应性。没有安全的进程级离线开关，本轮没有伪造离线测试。

模型下载需要用户通过系统界面授权。已编译独立SwiftUI授权探针，但本报告尚未把授权视为完成。完成下载后，应在用户明确操作后重新运行同一PoC；不要通过shell自动化系统设置或下载流程。随后才可以测：

1. 首轮会话准备和24句批量翻译；
2. 同一会话第二、三轮暖批量；
3. `getrusage`/RSS结果和每句输出；
4. 关闭网络后的翻译成功率；
5. UI宿主中的主线程响应。

## 建议

当前结论为 **C**。Apple Translation API和目标语言对已确认可用，但本机模型尚未安装，不能据此决定接入产品。

完成模型下载并取得三轮实测后：

- **A**：质量和延迟达到歌词使用门槛，且离线通过；
- **B**：API可用但质量、延迟或离线有明显限制，只适合作为可选功能；
- **C**：模型/权限/服务仍阻塞，继续不接入。
