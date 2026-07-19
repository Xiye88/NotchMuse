# Final UX Release Report

Task: 04_UX Final Clean Install User Journey

Status: Completed with Manual Permission Caveat

Priority: P0

## Findings

- `NotchMuse.app` launches from the generated release artifact.
- The app appears as a single NotchMuse process.
- Spotify is readable in the current user environment.
- Lyrics display is visible in Status Bar / Notch Mode during the PM screenshot pass.
- Settings can be opened through the NotchMuse menu.
- DMG install simulation completed:
  - DMG mounted.
  - `NotchMuse.app` copied from DMG to a temporary `Applications` folder.
  - Copied app launched successfully.
  - NotchMuse process confirmed from the copied app path.

## Problems Found

- macOS permission prompts cannot be fully re-triggered without a clean user account, test machine, or permission reset.
- Gatekeeper `Control-click Open` / `Open Anyway` flow still needs final manual verification from the downloaded GitHub DMG because local builds do not fully reproduce browser download quarantine.

## Recommended Actions

- Optional final manual install from the uploaded GitHub Release DMG:
  - download DMG from GitHub
  - open DMG
  - drag to Applications
  - launch with unsigned Gatekeeper flow
  - allow Spotify Automation
  - play Spotify track
  - confirm lyrics
  - open Settings
  - quit and relaunch

## Need PM Decision

- Confirm whether current-user + DMG simulation is enough for beta, or whether a clean macOS user account must be used before publishing.
