<p align="center">English | <a href="README.zh-CN.md">简体中文</a></p>

<h1 align="center">NotchMuse v0.8.0</h1>

<p align="center">Synced lyrics in your Mac menu bar, beside the notch, or at the edge of your screen.</p>

<p align="center">macOS 14+ · Apple Silicon · Spotify · Apple Music · NetEase Cloud Music · QQ Music · Soda Music</p>

<p align="center"><a href="https://notchmuse.com"><strong>Download from website</strong></a> · <a href="https://github.com/Xiye88/NotchMuse/releases"><strong>GitHub Releases</strong></a> · <a href="https://github.com/Xiye88/NotchMuse/issues"><strong>Report an issue</strong></a></p>

## Supported Players

Spotify · Apple Music · NetEase Cloud Music · QQ Music · Soda Music. Choose a player manually or let Auto Detect follow the one currently playing.

## Core Features

| Lyrics display | Personalization | Everyday use |
| --- | --- | --- |
| Status Bar and Notch lyrics | Solid and gradient colors | Auto Detect |
| Left or right side lyrics | Background, opacity, and width | English and Simplified Chinese |
| Lyrics above the Dock | Appearance presets | In-app update controls |
| Custom width and position | System, Light, and Dark appearance | Launch at Login; Dock and menu bar icon controls |

NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. No Homebrew or separate helper installation is needed. Compatibility can change after a macOS or player update.

## Screenshots

<!-- SCREENSHOT_REFRESH_PENDING_PO: Add final v0.8.0 Settings, Status Bar, Notch, side, and Dock screenshots. Do not reuse the older Settings capture. -->

The refreshed gallery is being prepared. See the [Status Bar demo](docs/assets/demos/notchmuse-status-bar-demo.mp4) and [Notch demo](docs/assets/demos/notchmuse-notch-mode-demo.mp4).

## Quick Start

1. [Download NotchMuse](https://notchmuse.com), open the DMG, and drag the app to Applications.
2. Open a supported desktop player and play a song. Allow macOS Automation access for Spotify or Apple Music if asked.
3. Open NotchMuse, keep Auto Detect selected, and choose your lyric position in Settings.

## Installation and Security

NotchMuse is distributed directly through the website and GitHub. Apple Developer ID signing and notarization are not configured yet, so macOS may show a first-launch security warning. This is a distribution-signing limitation, not a version status.

If macOS blocks the app, open **System Settings → Privacy & Security → Open Anyway** for NotchMuse, authenticate if asked, then open it again. See [Support](SUPPORT.md) for installation and permission help. Intel Macs are not supported.

## Automatic Updates

Starting with v0.8.0, use **Settings → General → Check for Updates…** to discover, download, and install signed updates. Manual checks work even when automatic checks are disabled. Sparkle verifies updates with EdDSA before installation and relaunch.

If you're using Beta 3 or an earlier version, install v0.8.0 manually once. Those older builds do not include the updater.

## FAQ

**A song has no lyrics?** Coverage depends on third-party lyrics providers; player support does not guarantee a match for every song.

**Does NotchMuse upload audio?** No. It reads playback metadata, then may send title, artist, album, and duration to a lyrics provider for matching. It does not collect telemetry or require an account.

**Why is the menu bar icon missing?** Another menu bar utility may hide it. NotchMuse does not manage other apps' menu bar icons.

## Support NotchMuse

The app includes a Support page. You can also use these QR codes:

| WeChat Pay | USDT · EVM | USDT · TRON |
| --- | --- | --- |
| <img src="MenuBarLyrics/Resources/WeChatSupport.jpg" alt="WeChat Pay QR code" width="150"> | <img src="docs/support/usdt-evm.png" alt="USDT EVM QR code" width="150"> | <img src="docs/support/usdt-trc20.png" alt="USDT TRON QR code" width="150"> |

The EVM address supports Ethereum, BNB Smart Chain (BEP20), Arbitrum, and Optimism. TRON uses a separate TRC20 address. Confirm the network before sending USDT. The [supporters list](docs/support/supporters.json) includes only people who consented to public credit.

## License and Feedback

NotchMuse is MIT-licensed; bundled third-party components are documented in [Third-Party Notices](THIRD_PARTY_NOTICES.md). Read [Support](SUPPORT.md) and [Feedback](FEEDBACK.md), or [open an issue](https://github.com/Xiye88/NotchMuse/issues). Developer and build documentation lives in [docs/README.md](docs/README.md).
