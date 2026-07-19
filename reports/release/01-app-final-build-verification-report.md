# Final Build Verification Report

Task: 01_APP Final Build Verification Report

Status: Completed with P0 release blocker

Priority: P0

## Findings

- 当前 NotchMuse App 使用 Swift Package Manager：
  - `MenuBarLyrics/Package.swift`
  - `swift-tools-version: 6.0`
  - `platforms: macOS 14`
  - 无第三方 Swift package dependency
- 当前本机工具链：
  - Swift: `Apple Swift version 6.3.3`
  - Target: `arm64-apple-macosx26.0`
  - Command Line Tools: `/Library/Developer/CommandLineTools`
  - SDK: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`
- Fresh checkout 模拟方式：
  - 使用 `git archive HEAD` 导出 tracked `HEAD` 到 `/tmp/notchmuse-final-fresh`
  - 这个模拟能反映 GitHub clone 后用户会拿到的文件状态
- Fresh checkout build/self-test 结果：
  - Command: `swift run --package-path /tmp/notchmuse-final-fresh/MenuBarLyrics NotchMuse --self-test`
  - Result: `Self-tests passed`
  - 结论：当前 tracked `HEAD` 可以构建并通过 self-test
- 当前 working tree build/self-test 结果：
  - Command: `swift run --package-path MenuBarLyrics NotchMuse --self-test`
  - Result: `Self-tests passed`
- 当前 working tree Release build 结果：
  - Command: `./scripts/build_release.sh 0.3.0-beta 3`
  - Result: generated `/Users/carlos/Documents/歌词/dist.noindex/NotchMuse.dmg`
  - DMG verify: `checksum ... is VALID`
  - Code signing: ad-hoc signed
  - Gatekeeper: script warns `macOS Gatekeeper warning is expected`

## Problems Found

- P0: Fresh checkout 通过的是 tracked `HEAD` 的旧源码状态，不是当前 working tree 的 Beta RC 状态。
- 当前 `git status --short` 显示大量 modified / untracked 文件，Release commit 尚未准备完成。
- 当前 Git tracked 文件缺少多个 Beta RC 必需文件。`git ls-files` 没有包含：
  - `CHANGELOG.md`
  - `RELEASE_CHECKLIST.md`
  - `scripts/build_dmg.sh`
  - `scripts/build_release.sh`
  - `MenuBarLyrics/Resources/NotchMuse.entitlements`
  - `MenuBarLyrics/Resources/en.lproj/*`
  - `MenuBarLyrics/Resources/zh-Hans.lproj/*`
  - `MenuBarLyrics/Sources/MenuBarLyrics/AccessibilityManager.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/AppLocalization.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/DebugLog.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/SettingsWindowController.swift`
  - `MenuBarLyrics/Sources/MenuBarLyrics/SodaMusicLyricsSource.swift`
  - `reports/release/01-app-final-build-verification-report.md`
- Fresh checkout 文件清单中只看到旧发布脚本：
  - `scripts/build_app.sh`
  - `scripts/run_app.sh`
  - `scripts/run_live_matrix.sh`
  - 缺少当前 RC 打包所需的 `build_dmg.sh` / `build_release.sh`
- 当前 working tree 的 Release build 可用，但 GitHub 用户 fresh clone 后无法获得同一套 RC 源码与脚本。
- 在普通 sandbox 权限下，SwiftPM 会在 manifest 阶段失败：
  - Error: `sandbox-exec: sandbox_apply: Operation not permitted`
  - 沙盒外验证已通过，因此该问题判断为当前 Codex 执行环境限制，不是 App 代码 blocker。
- Release artifact 仍是 ad-hoc signed。公开 GitHub Beta 可以发布，但用户会遇到 Gatekeeper warning；如果要求更顺滑安装，需要 Developer ID signing + notarization。

## Recommended Actions

- 先完成 Release commit，不要直接用当前 dirty working tree 发布。
- Release commit 最少应包含：
  - 当前 App source changes
  - localization resources
  - `NotchMuse.entitlements`
  - `CHANGELOG.md`
  - `RELEASE_CHECKLIST.md`
  - `scripts/build_dmg.sh`
  - `scripts/build_release.sh`
  - `reports/release/*`
- Release commit 后重新做真正 Fresh Clone verification：
  - `git clone <repo> /tmp/notchmuse-clean`
  - `swift run --package-path /tmp/notchmuse-clean/MenuBarLyrics NotchMuse --self-test`
  - `/tmp/notchmuse-clean/scripts/build_release.sh 0.3.0-beta <final-build>`
- 保持 `.build/`、`.DS_Store`、`dist.noindex/` 不进入 Git。
- 如果继续使用 ad-hoc signed Beta，需要 README / Release Notes 明确说明 Gatekeeper `Open Anyway` 流程。

## Need PM Decision

- 是否将当前所有 NotchMuse RC untracked files 纳入 GitHub Beta Release commit？
- `lyrics-provider-benchmark/` 是否跟 NotchMuse 主 App 一起开源，还是作为独立实验室项目另行发布？
- `reports/` 是否全部进入仓库，还是只保留 release 相关报告？
- `0.3.0-beta` 的最终 Build Number 是否继续使用 `3`？
- GitHub Beta 是否接受 ad-hoc signed DMG，还是发布前必须完成 Developer ID signing + notarization？
