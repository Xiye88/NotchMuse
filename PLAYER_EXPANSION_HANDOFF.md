# QQ Music and Soda Music Expansion QA

Date: 2026-09-26

## Scope

- Baseline: `main` / `776437a352d8f81ce6915c4779766f91d3142047`.
- Branch: `codex/player-expansion-integration`.
- Add QQ Music (`com.tencent.QQMusicMac`) and Soda Music (`com.soda.music`) to
  explicit selection and Auto Detect using the existing MediaRemote bridge.
- Keep existing QQ/Soda lyric providers. No Production Matcher, provider
  priority, transport-control, or release changes.

## Implementation

- Added QQ Music and Soda Music player sources, adapters, Settings labels, and
  adapter snapshot ownership/state mapping.
- Added checks for playback-state mapping, foreign-owner rejection, closed and
  stopped state handling, settings persistence, bundle IDs, and Auto Detect
  selection/handoff.
- A failed initial bridge health check is retried on a later snapshot.

## Results

- Debug build: PASS.
- Debug `--full-self-test`: PASS.
- Release candidate `0.8.0` build `21`: PASS, arm64, ad-hoc signed.
- Packaged `--self-test`: PASS.
- `codesign --verify --deep --strict`: PASS.
- `hdiutil verify`: PASS.
- App and DMG SHA-256 manifest verification: PASS.
- English/Simplified Chinese localization parity: PASS, 119 keys each.
- `git diff --check`: PASS.
- Current read-only MediaRemote probe: both QQ and Soda processes are running;
  Soda is the current owner and reports playing state, title, artist, album,
  duration, and elapsed position. QQ live playback had passed a prior probe;
  this run did not interrupt Soda to force an ownership change.
- Existing QQ Music and Soda Music lyric sources remain registered in
  `LyricsClient`; provider priority is unchanged.

## Open Gates

- `swift test`: BLOCKED locally because the active Command Line Tools toolchain
  does not provide `XCTest`. Run the formal suite with macOS 15 CI.
- Product Owner GUI confirmation remains open for visible synchronized lyrics,
  player handoff, pause/resume, and app/player restart recovery.
- Restart/lifecycle and real lyric retrieval have not been re-run in the new
  candidate.
- MediaRemote seek was not available during the earlier Soda probe. Seek,
  Next, and Previous are observations of changes made in the player; NotchMuse
  remains read-only for transport controls.
- The backend uses a private macOS framework and may require maintenance if
  macOS changes its behavior.

No merge to `main`, push, tag, or public release was performed.
