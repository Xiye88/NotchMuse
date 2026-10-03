# Final Artifact Report

Task: 02_RELEASE Final Artifact Report

Status: Ready for GitHub unsigned beta artifact

Priority: P0

## Findings

- 本阶段目标是 GitHub Open Source Beta Release，当前 artifact 允许 unsigned/ad-hoc，不要求 Developer ID signing、Apple notarization、stapling 或 Gatekeeper accepted。
- 已重新执行 `./scripts/build_release.sh 0.3.0-beta 3`，成功生成最终 unsigned DMG：
  - `dist.noindex/NotchMuse.dmg`
- Release script 当前流程有效：
  - 清理 `dist.noindex`
  - 执行 Swift release build
  - 运行 app self-tests
  - 生成 `NotchMuse.app`
  - 创建 `NotchMuse.dmg`
  - 执行 `codesign --verify`
  - 执行 `hdiutil verify`
  - 输出 unsigned beta warning
- Final artifact metadata：
  - Bundle ID: `app.notchmuse.mac`
  - Version: `0.3.0-beta`
  - Build: `3`
  - Architecture: `arm64`
- Final signing 状态符合 unsigned beta：
  - `NotchMuse.app` 是 ad-hoc signed。
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.app` 显示 `Signature=adhoc`、`TeamIdentifier=not set`。
  - `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app` 通过。
  - `NotchMuse.dmg` 是 unsigned，`codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg` 显示 `code object is not signed at all`。
- Final DMG 校验通过：
  - `hdiutil verify dist.noindex/NotchMuse.dmg` 显示 checksum valid。
  - SHA-256: `f956eb31915ea8c69431c93542e6a34797d3e081c4f493872faa254c79664c99`
- Release 文件结构当前为：
  - `dist.noindex/NotchMuse.app`
  - `dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `dist.noindex/NotchMuse.app/Contents/MacOS`
  - `dist.noindex/NotchMuse.app/Contents/Resources`
  - `dist.noindex/NotchMuse.app/Contents/_CodeSignature`
  - `dist.noindex/NotchMuse.dmg`
- README 已包含 macOS security warning / Open Anyway 说明：
  - GitHub beta 是 unsigned。
  - macOS 可能阻止首次打开。
  - 用户应在 Finder 里 Control-click `NotchMuse.app`，选择 `Open`，再确认 `Open`。
  - 如果仍被阻止，进入 `System Settings > Privacy & Security`，选择 `Open Anyway`。
- RELEASE_CHECKLIST 已按 unsigned beta 更新：
  - Gatekeeper warning documented and expected
  - Control-click Open flow tested
  - Open Anyway flow tested

## Problems Found

- 未发现阻止 GitHub unsigned beta artifact 发布的 Critical blocker。
- 预期问题：普通用户首次打开会看到 macOS security warning，因为 app 不是 Developer ID signed，也没有 notarized。
- `Open Anyway` 真实体验仍需要从 GitHub Releases 下载后的 clean-machine 验证；本地 `dist.noindex` 不能完全模拟浏览器下载后的 quarantine 行为。
- Final GitHub Release asset 尚未上传，因此还不能验证：
  - GitHub 下载后的 SHA-256 是否匹配
  - 用户从下载目录 mount DMG 是否正常
  - drag-to-Applications 是否正常
  - 首次打开是否能按 README 的 Control-click Open / Open Anyway 路径完成
- DMG 内部 Finder mount 布局本轮没有重新作为最终步骤执行；当前结构由 `scripts/build_dmg.sh` 保证：staging `NotchMuse.app` 并创建 `Applications -> /Applications` symlink。

## Recommended Actions

- GitHub Release 上传文件：
  - `dist.noindex/NotchMuse.dmg`
- GitHub Release body 必须包含：
  - Artifact name: `NotchMuse.dmg`
  - Version: `0.3.0-beta`
  - Build: `3`
  - SHA-256: `f956eb31915ea8c69431c93542e6a34797d3e081c4f493872faa254c79664c99`
  - Platform: macOS 14.0+, Apple Silicon / `arm64`
  - Unsigned beta notice
  - Install steps: download DMG, drag app to Applications
  - Open steps: Control-click Open, then `System Settings > Privacy & Security > Open Anyway` if needed
  - Developer ID signing / notarization deferred to future Distribution Phase
- 发布前 clean verification commands：
  - `./scripts/build_release.sh 0.3.0-beta 3`
  - `plutil -extract CFBundleIdentifier raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `plutil -extract CFBundleShortVersionString raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `plutil -extract CFBundleVersion raw dist.noindex/NotchMuse.app/Contents/Info.plist`
  - `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app`
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.app`
  - `codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg`
  - `hdiutil verify dist.noindex/NotchMuse.dmg`
  - `shasum -a 256 dist.noindex/NotchMuse.dmg`
- 上传后 clean verification commands / manual checks：
  - 从 GitHub Releases 下载 `NotchMuse.dmg`
  - `shasum -a 256 NotchMuse.dmg`
  - Finder mount DMG
  - 确认 DMG 内包含 `NotchMuse.app` 和 `Applications` shortcut
  - 拖入 Applications
  - Control-click Open
  - 如被阻止，验证 `System Settings > Privacy & Security > Open Anyway`
  - 首次访问 Spotify 时确认 Automation permission prompt

## Need PM Decision

- 确认最终 GitHub tag：建议 `v0.3.0-beta`。
- 确认当前 build number `3` 是否就是最终 beta artifact build。
- 确认 GitHub Release wording 使用 `unsigned GitHub beta` 还是 `open-source beta`。
- 确认是否必须在发布前补齐 screenshots；当前 artifact 本身已 ready，但 release page polish 仍取决于 PM 标准。
- 指定上传后 clean-machine verification owner，负责确认 GitHub 下载、checksum、DMG mount、drag install、Control-click Open / Open Anyway。
