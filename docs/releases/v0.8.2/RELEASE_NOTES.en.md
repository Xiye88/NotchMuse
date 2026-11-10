# NotchMuse v0.8.2

Build70 · Stable release package candidate · **Publication pending**

macOS 14+ · Apple Silicon · [简体中文](RELEASE_NOTES.zh-CN.md)

## Changes since v0.8.1 Build61

- **Place lyrics where you want.** Drag the free-position lyric frame, switch between horizontal and vertical layouts, and keep saved positions. When display arrangements change, the frame returns within the visible screen.
- **Lock without blocking your desktop.** Locked lyrics let clicks reach the app underneath. A small unlock control stays accessible; the expanded toolbar provides move, color, lock, orientation, settings and close controls. Reselecting the display mode restores a closed lyric frame.
- **Highlighting follows available timing.** Genuine word timing takes priority, followed by genuine line endings. A completed line stays highlighted until the next line starts. When neither is available, the whole line stays lit instead of guessing a singing duration from the gap. Static vertical lyrics keep their opening text visible.
- **Preserve usable NetEase timing.** A malformed line no longer discards valid word timing elsewhere in the response. Mixed-quality lyrics retain usable timing without relaxing recording identity checks.
- **Clearer update feedback.** Update checks distinguish a confirmed current version from an unknown status. Connection failures offer a retry after the current check finishes.

## Installation and availability

This candidate is not yet publicly downloadable. After publication, download the official DMG from [GitHub Releases](https://github.com/Xiye88/NotchMuse/releases), quit the old Stable app and replace it in Applications. Keep Preview separate.

**Manual installation is required.** The official Sparkle feed remains at Build47. Automatic installation, relaunch and recovery to the previous version remain unverified for this package.

The app is ad-hoc signed, without Developer ID signing or Apple notarization. Lyrics depend on third-party availability; some songs or versions may have no match.
