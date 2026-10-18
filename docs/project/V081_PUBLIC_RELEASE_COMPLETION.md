# NotchMuse v0.8.1 / Build61 — Public Release Completion

**结果：已正式公开发布，官网已部署；本次为手动下载安装。**

## 公开入口与冻结产物

| 项目 | 实际结果 |
| --- | --- |
| GitHub Release | [v0.8.1 / Build61](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1)，正式版、Latest，非草稿/预发布 |
| 官网 | [English](https://notchmuse.com/) · [简体中文](https://notchmuse.com/zh/) |
| DMG | [NotchMuse.dmg](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/NotchMuse.dmg)，6,802,591 字节 |
| 校验文件 | [SHA256SUMS](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/SHA256SUMS) |
| Git Tag / 公开源码 | `v0.8.1` → `8320271b4218431b66175bf40e203230ce8fa741`（annotated tag） |
| Bundle / Version / Build | `app.notchmuse.mac` / `0.8.1` / `61`，arm64，macOS14+ |
| 签名 | ad-hoc；没有 Developer ID 签名，未经 Apple 公证 |

```text
d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851  NotchMuse.dmg
```

DMG 保持冻结，未重打包。原构建源码为 `4c392efbd8da0c8abb0fdc70833575192e18d7d1`；公开发行提交保留全部79个运行/打包输入的相同字节，并建立在最新网站 main 上。不同提交号来自安全整理公开源码及发行文档，不代表重新构建安装包。[来源映射](../releases/v0.8.1/SOURCE_PROVENANCE.json)。未推送私有开发分支历史、密钥、私有配置、调试日志或测试用户资料。

## 已通过

- 冻结474项既有自动化检查及15项生产候选契约检查可复用；本轮重验 DMG/SHA256、签名完整性及实际包自测通过。未更改歌词算法，也未重复要求 Accepted 歌曲人工验收。
- [main 发行源码 CI](https://github.com/Xiye88/NotchMuse/actions/runs/39115633205) PASS：Debug/Release、Swift Package tests、打包自测、DMG、哈希、bridge 和本地化。本地 Command Line Tools 缺少 XCTest 的限制仍如实保留，未声称本地完整 XCTest 通过。
- GitHub 6项上传资源大小及服务器摘要正确；正式 Release 页面已在浏览器中实际打开，Tag 指向核对通过。中英文 README、CHANGELOG、中英文 Release Notes 已公开。
- 匿名公开 DMG 下载通过；中英文官网 Hero 按钮均实际触发浏览器原生下载，两次文件均为同一冻结 SHA256，未同意统计时无 Google 请求。
- 官网53个公开 URL 校验通过；12个中英文页面、36个下载入口全部指向 v0.8.1。实际公网桌面1440px和移动360px渲染无横向溢出；canonical、12项 sitemap、robots、媒体及静态资源正确。已部署内容与源文件一致（HTML 比对仅移除已知 Cloudflare 自动插入的 beacon 标签）。
- SEO/GA4、同意及撤回机制和 CSP 均保留；GA4 `download_click.app_version` 从下载 URL 读取，本地事件测试已核验 `0.8.1`。未更改 GSC/Bing 账户或重复提交 sitemap。
- 本机 Stable47、Preview60 的 App 与偏好设置均与本轮基线相同；Stable47 完整 App/偏好回滚及旧 DMG 校验通过，仅保留两个常驻 App。公开 [v0.8.0](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.0) 和原资源仍在。

## Sparkle：未推送 v0.8.1

Build61 包可用 Build47 内置公钥验证 EdDSA 签名；篡改包/篡改签名会被拒绝。但缺少安全隔离会话中的真实47→61安装、重启、更新失败恢复证据，**这部分未完成，不能标为通过**。因此没有向正式 feed 推送 Build61。

[正式 appcast](https://notchmuse.com/appcast.xml) 仍为 Build47，原更新说明也保持原样。应用内“检查更新”不提供 v0.8.1。README、Release、官网均明确说明手动安装；自动更新独立保留为后续事项，不撤回已完成的手动分发。

## 安装、回滚和保留风险

打开官方 DMG，拖入“应用程序”，先退出旧正式版再替换。需要回滚时，应将旧 App 与对应偏好设置同时备份/恢复，勿覆盖 Preview。若 macOS 无法验证开发者，仅在信任官方来源并核对哈希后，按 [Apple 官方方式](https://support.apple.com/en-us/102445)使用“系统设置 → 隐私与安全性 → 仍要打开”。没有关闭 Gatekeeper，也不提供全局关闭安全机制的命令。

Developer ID、公证及独立干净 Mac 首次安装是 Product Owner 明确接受的本次限制，不是待批准阻塞。首次安装、Gatekeeper 和权限验收仍为 **NOT_TESTED**；未将本地模拟或当前用户运行冒充干净 Mac PASS。第三方歌词覆盖率及 MediaRemote 兼容性仍有既有限制。

官网保留上一部署用于回滚；下载可退回 v0.8.0，发布资产不原地替换。正式 feed 无需回滚，本轮从未修改。

## 剩余事项与交接

- **未完成：Sparkle 实际更新安装/重启/失败恢复资格验证及 v0.8.1 feed 推送。**
- 手动下载发行没有剩余必需的 Product Owner 操作；无需现在购买 Apple Developer 账号。
- PM Handoff、PROJECT_STATUS、TASK_BOARD、THREAD_REGISTRY 和 ROADMAP 已同步。不再自动启动算法优化或重复验收。
- [公开可安全保存的验证证据](../reports/release/v081-public-completion/)。本地完整执行资料及回滚继续保留。

```text
Current status: v0.8.1 / Build61 RELEASED; website deployed; manual installation.
Completed: Source/main/tag, GitHub assets, bilingual materials, website/download/hash checks,
local Stable47/Preview60 and rollback protection.
Pending confirmation: None for this completed publication. Sparkle installer E2E is separate and uncompleted.
Key files: docs/project/V081_PUBLIC_RELEASE_COMPLETION.md; docs/releases/v0.8.1/;
docs/reports/release/v081-public-completion/; website/.
Next step: Stop release execution; retain rollback and collect actual user feedback.
Do not repeat: Accepted-song manual QA, algorithm/source research, waived install/signing gates,
or automatic feed activation without real qualification.
```
