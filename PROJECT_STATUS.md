# NotchMuse Project Status

Last Updated: 2026-09-22

## Current Phase

v0.8 Production Quality Sprint — not released.

## Current Goal

Turn the existing three-player candidate into a release candidate by fixing
player selection and state regressions, completing Notch UX regression, and
passing the release artifact gates.

## Current Product State

- Spotify, Apple Music, and NetEase adapters exist in the candidate codebase.
- The current player is manually selected and defaults to Spotify. Player Auto
  Detect is not implemented.
- A regression report says the NetEase option disappeared from Settings after
  UX changes. The enum, Settings UI/datasource, adapter registration, and
  persistence must be verified and covered by a regression test.
- Notch background modes and hover behavior exist in the prior candidate, but
  their v0.8 defaults and GUI behavior remain release-gate work.
- The previous NetEase candidate reached `0.8.0` build `14`. Its local DMG was
  verified, but the current Production Quality Sprint RC has not been approved.

## Sprint Gates

### P0

1. Add Auto Detect as the recommended default for Spotify, Apple Music, and
   NetEase, while preserving explicit player selection.
2. Restore and regression-test all three Settings player options.
3. Clear stale lyrics whenever ownership or track identity changes.

### P1

1. Make Playing, Paused, and Stopped behavior deterministic. Stopped defaults
   to hiding lyrics; users may choose to keep the final lyric paused.
2. Verify lyric-only default presentation, `None / Black / Custom` backgrounds,
   and the Hide lyrics on hover toggle with ON as the default.

### P2 Release Candidate

1. Pass focused automated and real-player regression.
2. Build and verify the DMG and checksum.
3. Record the actual signing/notarization state; do not imply Developer ID
   signing when the build is ad-hoc signed.
4. Update release documentation, then request final approval before push, tag,
   or GitHub Release.

## Release Status

- v0.8 has not been merged to the release branch, pushed, tagged, or published.
- No v0.8 GitHub Release exists.
- Developer ID signing, notarization, and stapling remain incomplete unless a
  later release check proves otherwise.
- v0.6.0 and v0.6.1 remain the latest documented published milestones.

## Guardrails and Known Risks

- Production Matcher, thresholds, ranking, and Provider priority are frozen
  after the v0.7 evidence gate ended NO-GO.
- NetEase depends on bundled private MediaRemote behavior and needs lifecycle
  regression on the release candidate.
- A clean Mac/new-user Gatekeeper, TCC, installation, and first-play journey is
  still outstanding.
- The app is currently documented as Apple Silicon only.

## Future

`notchmuse.com` is planned after v0.8. It will provide a landing page, release
notes, DMG, checksum, and `latest.json` only; it will not host source code. The
website is not part of the current sprint.

See `TASK_BOARD.md` for owners and live status. The untracked candidate
`PROJECT_HANDOFF.md` remains the detailed build-14 evidence source.
