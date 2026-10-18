# NotchMuse v0.8.1

Build61 · macOS14+ · Apple silicon · manual installation.

[Download](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/NotchMuse.dmg) · [SHA256SUMS](https://github.com/Xiye88/NotchMuse/releases/download/v0.8.1/SHA256SUMS) · [简体中文](RELEASE_NOTES.zh-CN.md)

## Changes since v0.8.0 Build47

- Better Spotify lyric recovery using public track identity and complete artist information. No Spotify Premium, developer account or user API key is required by this lookup route.
- Select lyrics using recording evidence, artist/version checks and timeline bounds; reject conflicting versions instead of accepting the fastest nonempty result.
- Normalize multi-artist metadata and preserve source identity. Restore validated recording matches without disabling wrong-version protections.
- Recover NetEase native song identity only when fresh local playback state and current player ownership agree; revalidate on resume.
- Preserve line/word timing information and protect against stale results after switching tracks or players.
- Distinguish Searching, No Lyrics, search timeout and network failure in the interface. Production does not expose Preview selection diagnostics or enable the shadow service.

## Compatibility and limitations

macOS14 or later, Apple silicon. Supported player integrations remain Spotify, Apple Music, NetEase Cloud Music, QQ Music and Soda Music. Some rely on macOS private MediaRemote behavior and may change with system/player updates.

Lyrics depend on third-party availability and recording metadata. Some songs remain unavailable; first lookup can take several seconds during slow requests. This release does not promise every song or version. Engineering selectable counts are not human-verified accuracy rates.

This build is **ad-hoc signed, not Developer ID signed, and not Apple notarized**. No Apple Developer account is required for this chosen distribution route. Clean-Mac first-install verification is still pending; this document does not claim that verification passed.

## Install

Download only from the official GitHub Release or notchmuse.com. Compare `shasum -a 256 NotchMuse.dmg` with the matching release's `SHA256SUMS`. Open the DMG, drag NotchMuse into Applications, eject the image, then open the installed App. If macOS blocks the unverified developer, and you trust the verified official download, use **System Settings → Privacy & Security → Open Anyway**, then confirm Open. Do not disable Gatekeeper or remove quarantine with terminal commands. If macOS reports malware or a damaged App, stop and verify the download rather than forcing it to run. [Apple installation guidance](https://support.apple.com/en-us/102445).

Open a supported player and play music. Allow Automation access to Spotify/Apple Music if requested; the menu bar provides settings and Quit. Independent clean-Mac permission and first-launch testing has not been completed; no such test is reported as passed.

## Upgrade and rollback

This release uses **manual download and installation**. The existing Build47 update feed remains unchanged: Build61 is not offered through Sparkle. Its archive signature verifies against the existing update key, but real isolated Build47→61 installation/relaunch/failed-update recovery has not passed; cryptographic checks alone do not qualify automatic updates.

Quit the old Stable before replacing it manually. Keep its App and preferences backed up together; rollback means quitting the new version and restoring both from the same backup. Preview remains separate. Never overwrite Preview with the Stable package. Existing v0.8.0 downloads remain available for rollback.
