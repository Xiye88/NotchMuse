# NotchMuse Current Handoff

## Current status

NotchMuse **v0.8.0 Build 47 is released**. Its GitHub asset, official signed update feed, website download, and installed Stable app were verified. This documentation cleanup does not change the app or publish a new version.

## Current architecture

The macOS app lives in `MenuBarLyrics/`. Spotify and Apple Music have player adapters; NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. `LyricsClient` tries ordered lyric providers and `TrackMatcher` conservatively validates matches. Production matcher thresholds and provider priority are frozen. Sparkle 2 uses a signed official feed; Preview uses separate identity and never enters that feed.

## Open work

No active P0. Optional follow-ups are refreshed screenshots/demo, broader clean-Mac evidence, Developer ID/notarization, and separately approved features. Menu Bar Space is paused and archived, not part of Stable.

## References

- **Start here:** [Master handoff](NOTCHMUSE_MASTER_HANDOFF.md)
- [Current status](PROJECT_STATUS.md) · [Task board](TASK_BOARD.md) · [Thread registry](THREAD_REGISTRY.md) · [Roadmap](ROADMAP.md)
- [Pre-cleanup detailed handoff](../archive/PROJECT_HANDOFF-through-v0.8.0.md) · [release evidence](../reports/v0.8.0-release-verification.md)
