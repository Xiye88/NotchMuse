# Beta Support

NotchMuse is currently an early public beta. This page covers the most common setup and troubleshooting steps before opening an issue.

## Install and open the unsigned beta

The GitHub beta is unsigned. macOS may block the first launch because the app is not signed with Apple Developer ID yet.

Try this first:

1. Move `NotchMuse.app` to `Applications`.
2. In Finder, open `Applications`.
3. Control-click `NotchMuse.app`.
4. Choose `Open`.
5. Confirm `Open` again.

If macOS still blocks it, open `System Settings > Privacy & Security` and choose `Open Anyway` for NotchMuse.

## Spotify permission

NotchMuse reads the current Spotify track through macOS Automation.

If lyrics do not appear:

1. Make sure the Spotify desktop app is open and playing a song.
2. When macOS asks whether NotchMuse can control Spotify, choose `Allow`.
3. If you denied the prompt, check `System Settings > Privacy & Security > Automation` and allow NotchMuse to control Spotify.
4. Restart NotchMuse after changing the permission.

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
