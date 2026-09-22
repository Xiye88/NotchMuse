# NotchMuse Project Status

Last Updated: 2026-09-23

## Current Phase

v0.8 Stability Fix Sprint — focused QA active, release prohibited.

## Current Goal

Validate the merged NetEase, playback-based Auto Detect, and Settings/Notch UX
changes against real players and GUI behavior.

## Current Product State

- Spotify, Apple Music, and NetEase adapters exist in the candidate codebase.
- Auto Detect is the default and supports Spotify, Apple Music, and NetEase by
  bundle ID. Explicit player overrides remain available.
- Settings exposes Auto Detect plus all three players. Enum, datasource,
  persistence, bundle IDs, and adapter factory are covered by self-tests.
- Playing and non-playing behavior is deterministic. The default Hide policy
  covers pause, player exit, and source switching; Keep retains the last lyric
  while progress and marquee scrolling remain stopped.
- Track ownership and native identity changes clear old lyrics before loading;
  stale asynchronous results cannot overwrite a newer track.
- Notch supports None/Black/Custom backgrounds, hover hiding, arbitrary lyric
  color, numeric inputs, and functional custom width; GUI QA is active.
- The integrated candidate reached local `0.8.0` build `15`. Automated build,
  self-test, deep signature verification, and DMG verification pass, but the
  release candidate has not completed real-player or clean-install QA.

## Sprint Gates

### P0.1 — DONE

`/Applications/NotchMuse.app` is the only installed and Spotlight-visible copy.
It is `0.8.0` build `15`, its executable matches the verified build output,
and LaunchServices has one running entry. Build 7 and build 14 were moved to
Trash, not permanently deleted. Preferences were preserved and Player Source
was set to Auto Detect. No login item or orphan helper was found; the current
watchdog/Perl pair belongs to build 15.

### P0.2 — IMPLEMENTED / MULTI-PLAYER QA PENDING

Auto Detect is selected. In the focused build-15 runtime check, Spotify and
Apple Music were closed, NetEase was running and playing as
`com.netease.163music`, and NotchMuse visibly rendered the current lyric.
Offline checks cover all bundle IDs, selection priority, current-owner
retention, adapter registration, and stale-result rejection. Real switching
among multiple open players remains part of `07_QA`.

### P0 — DONE

1. Add Auto Detect as the recommended default for Spotify, Apple Music, and
   NetEase, while preserving explicit player selection.
2. Restore and regression-test all three Settings player options.
3. Clear stale lyrics whenever ownership or track identity changes.

### P1 — IMPLEMENTED / QA PENDING

1. Make Playing, Paused, and Stopped behavior deterministic. Stopped defaults
   to hiding lyrics; users may choose to keep the final lyric paused.
2. Verify lyric-only default presentation, `None / Black / Custom` backgrounds,
   and the Hide lyrics on hover toggle with ON as the default.

### P2 Release Candidate — NOT STARTED IN THIS SPRINT

1. Pass focused automated and real-player regression.
2. Build and verify the DMG and checksum.
3. Record the actual signing/notarization state; do not imply Developer ID
   signing when the build is ad-hoc signed.
4. Update release documentation, then request final approval before push, tag,
   or GitHub Release.

## Release Status

- Stability integration commits: `28d7a3b` (App) and `46dc4f5` (UX) on
  `codex/netease-production-candidate`.
- Local artifact: `0.8.0` build `15`; DMG SHA-256
  `215b80865bbfb114a79a75bf9626624b9d3570be8620aaca7c001bfd6930ff76`.
- Release binary self-test, `codesign --verify --deep --strict`, and
  `hdiutil verify` pass.
- The app is arm64 and ad-hoc signed with no Team ID. Gatekeeper rejects it;
  Developer ID signing, notarization, and stapling are not complete.
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

See `TASK_BOARD.md` for owners and live status. `PROJECT_HANDOFF.md` preserves
the detailed build-14 evidence and starts with the current build-15 handoff.
