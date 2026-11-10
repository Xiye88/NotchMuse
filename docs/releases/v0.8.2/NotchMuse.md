# NotchMuse v0.8.2

Build70 · Stable release

macOS 14+ · Apple Silicon · [简体中文](RELEASE_NOTES.zh-CN.md)

## Changes since v0.8.1 Build61

- **Place lyrics where you want.** Drag the free-position lyric frame, switch between horizontal and vertical layouts, and keep saved positions. When display arrangements change, the frame returns within the visible screen.
- **Lock without blocking your desktop.** Locked lyrics let clicks reach the app underneath. A small unlock control stays accessible; the expanded toolbar provides move, color, lock, orientation, settings and close controls. Reselecting the display mode restores a closed lyric frame.
- **Highlighting follows available timing.** Genuine word timing takes priority, followed by genuine line endings. A completed line stays highlighted until the next line starts. When neither is available, the whole line stays lit instead of guessing a singing duration from the gap. Static vertical lyrics keep their opening text visible.
- **Preserve usable NetEase timing.** A malformed line no longer discards valid word timing elsewhere in the response. Mixed-quality lyrics retain usable timing without relaxing recording identity checks.
- **Clearer update feedback.** Update checks distinguish a confirmed current version from an unknown status. Connection failures offer a retry after the current check finishes.

## Installation and availability

Download the official DMG from [GitHub Releases](https://github.com/Xiye88/NotchMuse/releases), quit the old Stable app and replace it in Applications. Keep Preview separate.

Existing Stable apps with Sparkle can check for updates and install this release after confirmation. Automatic checking follows the preference in Settings. Preview remains separate; Beta 3 and older need one manual installation.

The app is ad-hoc signed, without Developer ID signing or Apple notarization. Lyrics depend on third-party availability; some songs or versions may have no match.

## 简体中文

新增可拖拽歌词框；划色使用真实逐词或句尾时间，避免把两句之间的空音算进演唱时长；保留可用网易云逐词时间。已有 Sparkle 的正式版可在应用内检查更新并确认安装；自动检查遵循设置中的开关。Preview 保持独立。
