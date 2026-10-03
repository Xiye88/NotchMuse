# Task Completion Report

Task: 04_UX Clean User Journey Checklist

Status: Updated for GitHub unsigned beta DMG execution

Priority: P1

## Findings

- This is a preparation checklist for the GitHub open source unsigned beta DMG. Developer ID signing/notarization is now out of scope for this phase.
- Prior UX verification found the DMG layout shape expected for beta: `NotchMuse.app` plus an Applications alias/symlink.
- Prior UX verification found Gatekeeper rejection on the available artifact; this is expected for an unsigned beta and must be covered by explicit user-facing install instructions.
- Clean journey should be executed on a fresh macOS user account or clean VM, with no existing `app.notchmuse.mac` defaults and no prior NotchMuse TCC permissions.

Clean User Journey Checklist:

1. Download DMG
   - Use the GitHub Releases unsigned beta DMG supplied by release owner.
   - Record DMG filename, version, build, source URL/location, download time, SHA-256, macOS version, machine type.
   - Pass criteria: DMG downloads completely, checksum matches release notes, and Finder can mount it.

2. Install Applications
   - Mount DMG.
   - Confirm mounted window contains `NotchMuse.app` and Applications alias.
   - Drag `NotchMuse.app` to Applications.
   - Confirm `/Applications/NotchMuse.app` exists and matches expected version/build.
   - Pass criteria: install succeeds without terminal commands, overwrite prompt behavior is clear if an older app exists.

3. First Launch
   - Launch NotchMuse from `/Applications`.
   - If macOS blocks the unsigned app, test the documented path: Control-click or right-click NotchMuse, choose Open, then confirm Open in the security dialog.
   - If macOS still blocks launch, test System Settings > Privacy & Security > Open Anyway.
   - Confirm menu bar item appears.
   - Confirm first launch guide appears once on a clean profile.
   - Quit and relaunch once after guide confirmation.
   - Pass criteria: unsigned app warning is expected and recoverable using documented steps; after approval, no crash, no extra dock-style main window unless expected, first launch guide does not repeat after acknowledgement.

4. macOS Unsigned App Security Warning / Open Anyway
   - Capture the exact macOS warning copy.
   - Confirm the README/release notes explain the same route the tester actually used.
   - Confirm the user can complete launch without Terminal commands, quarantine removal commands, or disabling Gatekeeper globally.
   - Pass criteria: normal macOS Open/Open Anyway flow works for unsigned beta.

5. Spotify Permission
   - Trigger Spotify access by keeping Spotify installed and opening/playing a track.
   - Confirm Apple Events permission prompt text is understandable and references Spotify access.
   - Allow permission and confirm NotchMuse recovers without restart if possible.
   - Pass criteria: Spotify permission prompt appears at the right time, user can allow it, and NotchMuse can read Spotify state after authorization.

6. Accessibility Permission When Using Left
   - Switch to Status Bar + Left position to trigger Accessibility path.
   - Confirm macOS Accessibility prompt or System Settings guidance opens.
   - Grant Accessibility permission, then return to NotchMuse.
   - Pass criteria: Accessibility permission appears only when needed for Left position, user can complete it from visible guidance, NotchMuse does not loop prompts.

7. Spotify Connection
   - Test with Spotify not running.
   - Test with Spotify running but paused.
   - Test with Spotify playing.
   - Record menu status labels for each state.
   - Pass criteria: app shows not-running/waiting state when Spotify is closed, connected state when readable, and current track metadata when available.

8. Lyrics Display
   - Play at least one common English track and one common Chinese track.
   - Wait for lyrics search result.
   - Confirm lyrics appear in selected display mode.
   - Confirm paused playback shows an understandable paused state.
   - Confirm refresh lyrics works without breaking display.
   - Pass criteria: lyrics are readable, synchronized enough for beta, and fallback/error text is understandable when lyrics are missing.

9. Settings
   - Open Settings from the menu bar item.
   - Verify Display Mode toggles between Status Bar and Notch Mode.
   - Verify Status Bar Position controls show/hide appropriately.
   - Verify lyrics width, color, font size, animation speed, opacity, language, hide-on-hover, and launch-at-login controls render correctly.
   - Make one minimal visible setting change, such as color or font size.
   - Pass criteria: settings window opens, controls are not clipped, changes apply without restart where expected.

10. Restart Persistence
   - Quit NotchMuse.
   - Relaunch NotchMuse.
   - Confirm selected settings persist.
   - Restart macOS or log out/in if launch-at-login is enabled for this test.
   - Confirm Spotify permission remains usable after relaunch.
   - Pass criteria: user choices persist, no repeated onboarding, no repeated permissions unless macOS requires them.

Evidence to capture during execution:

- DMG Finder screenshot.
- Unsigned app security warning screenshot.
- Open Anyway / successful relaunch evidence.
- First launch guide screenshot.
- Apple Events permission prompt screenshot.
- Accessibility permission/System Settings screenshot.
- Menu opened with Spotify connected.
- Lyrics visible in menu bar/notch/status area.
- Settings window screenshot before and after one setting change.
- Short note with exact pass/fail result for each checklist step.

## Problems Found

- No GitHub Release unsigned beta DMG URL was provided in this phase, so execution is still pending.
- Unsigned app Gatekeeper warning is now expected, but the release must include clear user-facing instructions for Open/Open Anyway.
- Existing local machine state is unsuitable for clean first-run proof because previous NotchMuse defaults and permissions may already exist.

## Recommended Actions

- Run this checklist after release owner provides the GitHub unsigned beta DMG URL and checksum.
- Prefer a clean macOS VM snapshot so the test can be repeated after permission or installer failures.
- Treat any unrecoverable unsigned-app launch block, missing permission prompt, unreadable onboarding, or repeated permission loop as release-blocking for beta.
- Save screenshots and notes beside this report or in a dated UX evidence folder.

## Need PM Decision

- Confirm the exact GitHub release install wording for unsigned app launch: Control-click Open, then System Settings > Privacy & Security > Open Anyway if needed.
- Confirm target macOS versions for clean journey execution.
- Confirm whether Accessibility permission flow must be tested in beta scope, since it only applies to Status Bar + Left position.
- Confirm whether one clean machine pass is enough, or whether Intel and Apple Silicon both need separate UX passes.
