# Final UX Release Report

Task: 04_UX Final Clean Install User Journey

Status: Partially Completed

Priority: P0

## Findings

- `NotchMuse.app` launches from the generated release artifact.
- The app appears as a single NotchMuse process.
- Spotify is readable in the current user environment.
- Lyrics display is visible in Status Bar / Notch Mode during the PM screenshot pass.
- Settings can be opened through the NotchMuse menu.

## Problems Found

- A true clean-user first launch was not completed in this pass.
- macOS permission prompts cannot be fully re-triggered without a clean user account, test machine, or permission reset.
- Gatekeeper `Control-click Open` flow still needs final manual verification from the uploaded GitHub DMG.

## Recommended Actions

- Before publishing, run one final manual install from the release DMG:
  - open DMG
  - drag to Applications
  - launch with unsigned Gatekeeper flow
  - allow Spotify Automation
  - play Spotify track
  - confirm lyrics
  - open Settings
  - quit and relaunch

## Need PM Decision

- Confirm whether current-user UX verification is enough for beta, or whether a clean macOS user account must be used before publishing.
