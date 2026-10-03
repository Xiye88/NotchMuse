# NotchMuse v0.6.1 Beta

This stability patch fixes a false Apple Music Automation permission warning
that could appear during rapid song changes.

## Changes

- Improved Apple Music track-transition handling.
- Verified Apple Music and Spotify recovery after network interruption.
- Verified Apple Music and Spotify recovery after macOS sleep and wake.
- Re-ran English and Simplified Chinese Release self-tests.

## Installation

1. Download `NotchMuse.dmg`.
2. Open the DMG and drag `NotchMuse.app` to `Applications`.
3. Control-click NotchMuse, choose `Open`, and confirm the beta launch warning.

## macOS Signing Notice

This beta is ad-hoc signed and not notarized with Apple Developer ID. If macOS
blocks the first launch, open `System Settings > Privacy & Security` and choose
`Open Anyway` for NotchMuse.

## Known Issues

- Lyrics availability depends on third-party providers; some songs may return
  no result.
- Spotify may need a normal page reload if its own client does not recover after
  a network interruption.
- Intel Macs are not supported in this beta.

## Compatibility

- macOS 14.0 or later
- Apple Silicon
- Spotify desktop app or Apple Music
