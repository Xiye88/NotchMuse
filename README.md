# MenuBarLyrics

A small native macOS menu bar app that shows synced Spotify lyrics. It reads
the current song metadata from the local Spotify app using Apple Events.

## Use

1. Open Spotify and play a song.
2. Run `./scripts/build_app.sh`.
3. Open `dist/MenuBarLyrics.app`, or run `./scripts/run_app.sh`.
4. When macOS asks, allow the app to control Spotify.

The menu bar item shows the current lyric line. Long lines scroll inside the selected width.

Menu options:

- Pause/Resume Lyrics
- Width: Small, Medium, Large
- Refresh Lyrics
- Quit

## Notes

- Lyrics are fetched over the network from LRCLIB and may also use the
  experimental NetEase Cloud Music and lrcmux interfaces. Availability and
  accuracy vary by service.
- The app does not upload audio, require an account, write a persistent cache,
  or collect telemetry.
- Third-party services and lyric copyrights are subject to their respective
  terms and rights holders.
- The current app bundle is ad-hoc signed for personal testing, not distributed
  with a Developer ID or through the Mac App Store.
- This is a local Mac app. A VPS cannot display lyrics inside your Mac menu bar.
