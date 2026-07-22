# Final Repository Verification Report

Task: NotchMuse v0.3.0-beta Release Candidate Freeze - 01_APP Git Release State Verification

Status: Completed

Priority: P0

## Findings

- 当前仓库分支：`main`
- 当前 HEAD：`a01ad39 Update final beta artifact checksum`
- NotchMuse App Beta RC 必要文件已进入 Git tracking：
  - `CHANGELOG.md`
  - `RELEASE_CHECKLIST.md`
  - `RELEASE_NOTES_0.3.0-beta.md`
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
- 当前 App build dependency 简单：
  - Swift Package Manager
  - Apple Command Line Tools
  - macOS 14+
  - Apple Silicon / `arm64`
  - `MenuBarLyrics/Package.swift` 中无第三方 Swift package dependency
- Fresh clone verification 已执行：
  - Clone path: `/tmp/notchmuse-final-clone-a01ad39-1784439463`
  - Clone HEAD: `a01ad39 Update final beta artifact checksum`
  - Debug command: `swift run --package-path /tmp/notchmuse-final-clone-a01ad39-1784439463/MenuBarLyrics NotchMuse --self-test`
  - Debug result: `Self-tests passed`
- Fresh clone Release build 已执行：
  - Command: `/tmp/notchmuse-final-clone-a01ad39-1784439463/scripts/build_release.sh 0.3.0-beta 3`
  - Result: `Release candidate: /tmp/notchmuse-final-clone-a01ad39-1784439463/dist.noindex/NotchMuse.dmg`
  - DMG verify: `checksum ... is VALID`
  - Release self-test: `Self-tests passed`
- Release artifact metadata：
  - Bundle Identifier: `app.notchmuse.mac`
  - Version: `0.3.0-beta`
  - Build: `3`
  - Binary: `Mach-O 64-bit executable arm64`
  - Code signature structure: `codesign --verify --deep --strict` passed

## Problems Found

- 当前 artifact 仍是 ad-hoc signed：
  - `build_release.sh` 明确提示 `macOS Gatekeeper warning is expected`
  - 这不阻止 GitHub Beta 发布，但会影响普通用户首次打开体验
- 当前仍有 3 个未进入 Git tracking 的截图资产：
  - `docs/assets/notch-mode.png`
  - `docs/assets/settings.png`
  - `docs/assets/status-bar.png`
  - 这些文件看起来属于文档/Release screenshot，不属于 01_APP core build blocker

## Recommended Actions

- 以当前 `main` 的 `a01ad39` 作为 App RC repository baseline。
- GitHub Release Notes 需要明确说明：
  - 当前 Beta 是 Apple Silicon only
  - 当前 DMG 是 ad-hoc signed
  - 如遇 Gatekeeper，需要使用 `System Settings > Privacy & Security > Open Anyway`
- 不要把 `.build/`、`dist.noindex/`、`.DS_Store` 加入 release commit。

## Need PM Decision

- 是否接受 `0.3.0-beta` build `3` 作为最终 GitHub Beta build？
- 是否接受 ad-hoc signed DMG 发布，还是必须先完成 Developer ID signing + notarization？
- `docs/assets/*.png` 是否纳入 GitHub Release docs commit？
- `lyrics-provider-benchmark/` 是否作为独立项目另行开源，而不是放入 NotchMuse App release？
