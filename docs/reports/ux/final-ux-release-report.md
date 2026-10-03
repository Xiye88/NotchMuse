# Final UX Release Report

Task: 04_UX Final Clean Install User Journey

Status: Completed with clean-user limitations

Priority: P0

## Findings

- 测试对象：`dist.noindex/NotchMuse.dmg`
- 版本信息：`0.3.0-beta`，build `3`，bundle id `app.notchmuse.mac`
- DMG SHA-256：`f956eb31915ea8c69431c93542e6a34797d3e081c4f493872faa254c79664c99`
- DMG 可挂载，挂载点为 `/Volumes/NotchMuse`。
- DMG 内容符合预期：包含 `NotchMuse.app` 和指向 `/Applications` 的 `Applications` alias/symlink。
- `/Applications/NotchMuse.app` 原本存在，但与 DMG 内 RC app 不一致；已用 DMG 内 `NotchMuse.app` 覆盖安装到 `/Applications`。
- 安装后校验通过：`/Applications/NotchMuse.app` 与 DMG 内 `NotchMuse.app` 内容一致。
- `codesign --verify --deep --strict` 通过。
- `spctl` 返回 `rejected`，符合 GitHub unsigned beta 预期；这不是 Developer ID / notarization release。
- 使用精确路径启动 `/Applications/NotchMuse.app` 成功，进程为 `/Applications/NotchMuse.app/Contents/MacOS/NotchMuse`。
- Spotify 当前可读，测试时状态为 playing。
- NotchMuse 菜单状态读取成功：
  - `Spotify: Connected`
  - `Lyrics: Available`
  - `Song: Father Figure`
  - `Artist: Taylor Swift`
- 屏幕截图确认顶部 NotchMuse overlay 正在显示歌曲信息和歌词片段。
- 测试结束后 DMG 已卸载，`/Applications/NotchMuse.app` 保持运行。

## Problems Found

- 本机不是 clean user 环境：已有 `app.notchmuse.mac` defaults，`HasShownFirstLaunchGuide = 1`，所以 First Launch Guide 不能作为 clean first launch 完整验收。
- Spotify / Apple Events permission 没有出现新弹窗，推断是本机已有权限或授权状态；本轮只能确认授权后路径可用。
- macOS unsigned app security warning / Open Anyway 没有完整复现；本地 app 复制安装后可启动，但 GitHub 下载后的 quarantine 场景仍需要 clean machine 验证。
- Accessibility permission 未纳入本轮核心路径；只有使用 Status Bar + Left 时才需要单独验证。

## Recommended Actions

- GitHub Release notes 必须明确说明 unsigned beta 的打开方式：Control-click / right-click NotchMuse -> Open；如仍被拦截，进入 System Settings -> Privacy & Security -> Open Anyway。
- 用 clean macOS user 或 VM 再跑一次 GitHub 下载版 DMG，重点验证 quarantine、First Launch Guide、Apple Events permission 弹窗。
- 发布前保留本次 SHA-256，方便用户校验 DMG。
- 若 beta 面向普通非技术用户，建议把 unsigned app warning 作为 README 和 Release notes 的第一屏安装说明。

## Need PM Decision

- 是否接受 GitHub unsigned beta 在 clean-user 权限弹窗未完整复现的情况下发布。
- 是否要求在 Apple Silicon clean VM 上补一次 GitHub 下载路径验证。
- 是否把 Accessibility Left position 权限验证列为 v0.3.0-beta release blocker。
