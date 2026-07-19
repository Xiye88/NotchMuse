# Task Completion Report

Task: User Journey QA Report

Status: Completed with Needs Manual Verification items

Priority: P0

## Findings

- DMG artifact exists at `dist.noindex/NotchMuse.dmg`.
- DMG mounted successfully in read-only mode at `/Volumes/NotchMuse`.
- Mounted DMG contains `NotchMuse.app` and an `Applications` symlink/alias pointing to `/Applications`.
- Installed app already exists at `/Applications/NotchMuse.app`, version `0.3.0-beta`, build `3`.
- DMG app and installed `/Applications/NotchMuse.app` have matching file hashes, so installation was effectively already present; I did not overwrite the existing app.
- App code signature verification passed with `codesign --verify --deep --strict`.
- Gatekeeper assessment rejected both DMG/open and mounted app execution checks, with `spctl` reporting rejection / insufficient context. This needs release-owner review before public beta distribution.
- Launching `/Applications/NotchMuse.app` preserved a single running NotchMuse process and did not crash.
- NotchMuse is a menu bar/background app; no regular app window appears on launch, which matches expected menu bar behavior.
- Current environment was not a clean first launch: `HasShownFirstLaunchGuide = 1` already exists in `app.notchmuse.mac` defaults.
- Spotify was running and readable. Current observed Spotify state: paused, track `媚人`, artist `薛之謙`, album `媚人`.
- NotchMuse menu opened through macOS accessibility automation and showed: `Spotify：已连接`, `歌词：已找到`, `暂停歌词`, `状态栏位置`, `刷新歌词`, `设置…`, `退出`.
- Lyrics display was visually confirmed in the menu bar/status area: orange text showed `已暂停：词：薛之谦`.
- Settings opened successfully from the NotchMuse menu.
- Settings visually displayed core controls: display mode, status bar position, display screen, lyrics width/custom width, lyrics color, font size, animation speed, opacity, language, and launch at login.
- Accessibility permission path is implemented only for Status Bar + Left position via `AXIsProcessTrustedWithOptions` and opens System Settings Privacy Accessibility URL, but the fresh permission prompt was not triggered during this run because the current setting is Right position.
- Apple Events / Spotify permission path is implemented through AppleScript calls to Spotify and `NSAppleEventsUsageDescription` is localized in English and Simplified Chinese.

## Problems Found

- P0: Gatekeeper assessment rejected the release artifact/app. Even though `codesign` verification passed, `spctl` did not accept the DMG/app for normal distribution.
- P0: This was not a clean first-user environment. Existing app defaults and likely existing permissions mean first launch guide, Apple Events prompt, and Accessibility prompt cannot be fully verified from this run.
- P1: Direct TCC database inspection was blocked by macOS privacy protection (`authorization denied`), so permission grant state could not be independently confirmed through the database.
- P1: Accessibility prompt path was not manually exercised because selecting Left status bar position could alter the user's current preference/permission state.

## Recommended Actions

- Resolve Gatekeeper/notarization/release signing before beta handoff.
- Run one manual clean-machine QA pass on a fresh macOS user or VM:
  - Install from DMG by dragging to Applications.
  - Launch NotchMuse for the first time.
  - Confirm first launch guide appears once.
  - Confirm Apple Events prompt appears when Spotify is queried.
  - Confirm allowing Spotify access changes menu state to connected.
  - Switch to Status Bar + Left and confirm Accessibility permission guidance/prompt.
  - Confirm lyrics display while Spotify is actively playing.
- Keep current DMG layout: app plus Applications alias is correct.
- Use the already-installed matching `/Applications/NotchMuse.app` as evidence that install copy should work, but still manually verify drag-install UX on clean machine.

## Need PM Decision

- Decide whether beta can ship with current Gatekeeper rejection, or whether notarization/signing must block release. Recommendation: block release until Gatekeeper passes.
- Decide whether clean-machine first-launch permission QA is required before beta announcement. Recommendation: required for P0 release confidence.
- Decide whether Accessibility permission should be part of beta onboarding copy, since it is only needed for Left status bar position and may confuse users if presented too early.
