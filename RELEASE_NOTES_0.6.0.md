# NotchMuse v0.6.0

NotchMuse v0.6.0 adds Apple Music support while preserving the existing Spotify experience.

## Highlights

- Choose Spotify or Apple Music in Settings.
- Show synchronized lyrics in Status Bar Mode or Notch Mode.
- Recover cleanly when a player exits or Automation permission changes.
- Report a lyrics issue from the app with the current track details attached to a user-controlled email draft.
- Use NotchMuse in English or Simplified Chinese.

## Installation

1. Download `NotchMuse.dmg`.
2. Open the DMG and drag `NotchMuse.app` to `Applications`.
3. Control-click NotchMuse, choose `Open`, and confirm the unsigned beta warning.
4. Open Spotify or Apple Music and play a song.
5. Choose the player in NotchMuse Settings and allow macOS Automation when prompted.

## Unsigned macOS Notice

This beta is ad-hoc signed and not notarized with Apple Developer ID. If macOS blocks the first launch, open `System Settings > Privacy & Security` and choose `Open Anyway` for NotchMuse.

## Known Issues

- Lyrics availability depends on third-party providers; some popular songs may still return no result.
- Most providers supply line-level timing rather than word-by-word timing.
- Apple Music may not retain its current track after the Music app restarts. NotchMuse clears stale lyrics and recovers after playback resumes.
- Left Status Bar Mode requires Accessibility permission.
- Intel Macs are not supported in this beta.

## Compatibility

- macOS 14.0 or later
- Apple Silicon
- Spotify desktop app or Apple Music
