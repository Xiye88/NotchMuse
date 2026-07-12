# MenuBarLyrics

A small native macOS menu bar app that shows synced Spotify lyrics.

## Use

1. Open Spotify and play a song.
2. Run `./scripts/build_app.sh`.
3. Open `dist/MenuBarLyrics.app`.
4. When macOS asks, allow the app to control Spotify.

The menu bar item shows the current lyric line. Long lines scroll inside the selected width.

Menu options:

- Pause/Resume Lyrics
- Width: Small, Medium, Large
- Refresh Lyrics
- Quit

## Notes

- Lyrics come from LRCLIB, so some songs may not have synced lyrics.
- This is a local Mac app. A VPS cannot display lyrics inside your Mac menu bar.
