# NotchMuse Support

This page covers installation and troubleshooting for NotchMuse v0.8.0, before opening an issue.

## Install and Open

Direct downloads are ad-hoc signed, but not signed with Apple Developer ID or notarized. macOS may block first launch; this is a distribution-signing limitation, not a version status.

Try this first:

1. Move `NotchMuse.app` to `Applications`.
2. In Finder, open `Applications`.
3. Control-click `NotchMuse.app`.
4. Choose `Open`.
5. Confirm `Open` again.

If macOS still blocks it, open `System Settings > Privacy & Security` and choose `Open Anyway` for NotchMuse.

## Updates

Starting with v0.8.0, use Settings > General > Check for Updates to install signed updates. Manual checks remain available when automatic checks are off. Beta 3 or older builds need a one-time manual installation of v0.8.0.

## Music player Automation permission

NotchMuse reads the current Spotify or Apple Music track through macOS Automation.

NetEase Cloud Music, QQ Music and Soda Music use the bundled bridge, without Homebrew or an extra helper installation.

If lyrics do not appear:

1. Make sure the selected music player is open and playing a song.
2. When macOS asks whether NotchMuse can control Spotify or Music, choose `Allow`.
3. If you denied the prompt, check `System Settings > Privacy & Security > Automation` and allow NotchMuse to control the selected player.
4. Return to the player and resume playback. NotchMuse should recover automatically; use `Refresh Lyrics` if needed.

## Accessibility permission

Accessibility is only needed for Left Status Bar Mode so NotchMuse can avoid the active app's menu items.

If you do not want to grant Accessibility permission, use Right Status Bar Mode or Notch Mode.

## No lyrics or wrong lyrics

Lyrics coverage depends on third-party lyrics providers. Some songs may have no synced lyrics, incomplete timing, or an incorrect match.

Before opening an issue:

1. Try another song with clear title and artist metadata.
2. Use `Refresh Lyrics` from the NotchMuse menu.
3. Include the song title, artist, album, NotchMuse version, and display mode in your bug report.

## Menu bar display issues

Status Bar Mode needs enough menu bar space. If your menu bar is crowded, optional tools such as Ice, Thaw, or Bartender can free up space.

If the NotchMuse icon is hidden by a menu bar organizer, expand hidden icons or reopen NotchMuse.

## Still stuck?

Please read [FEEDBACK.md](FEEDBACK.md), then open a GitHub issue:

- Use [Bug report](https://github.com/Xiye88/NotchMuse/issues/new?template=bug_report.md) for reproducible problems.
- Use [Feature request](https://github.com/Xiye88/NotchMuse/issues/new?template=feature_request.md) for focused use cases or improvements.

Remove private information before attaching logs, screenshots, or screen recordings. Do not submit credentials, access tokens, private account names, personal files, or private messages.
