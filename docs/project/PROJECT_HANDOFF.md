# NotchMuse Current Handoff

## Current status

NotchMuse **v0.8.0 Build 47 is released**. Its GitHub asset, official signed update feed, website download, and installed Stable app were verified. The authorized media showcase refresh runs on `codex/media-showcase-refresh` from `84bb0c1`; it does not change the app or publish a new version.

## Current architecture

The macOS app lives in `MenuBarLyrics/`. Spotify and Apple Music have player adapters; NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. `LyricsClient` tries ordered lyric providers and `TrackMatcher` conservatively validates matches. Production matcher thresholds and provider priority are frozen. Sparkle 2 uses a signed official feed; Preview uses separate identity and never enters that feed.

## Open work

Product Owner rejected Round 1's narrow crops. Round 2 on `codex/media-showcase-refresh` replaces all three demos with full 16:9 desktop framing, synchronized across website and README, and changes only media container proportions. Local candidate is prepared; synchronization/deployment are pending. The source lacks a physical MacBook notch: the candidate shows the real settings preview plus top/Dock lyric positions, awaiting footage/direction and visual acceptance. Evidence: [current framing report](../reports/media/media-framing-fix-round2.md). The manual pause-control P2 remains open, outside this framing-only round. Broader clean-Mac evidence, Developer ID/notarization, and App features remain separate work. Menu Bar Space stays paused.

## References

- **Start here:** [Master handoff](NOTCHMUSE_MASTER_HANDOFF.md)
- [Current status](PROJECT_STATUS.md) · [Task board](TASK_BOARD.md) · [Thread registry](THREAD_REGISTRY.md) · [Roadmap](ROADMAP.md)
- [Pre-cleanup detailed handoff](../archive/PROJECT_HANDOFF-through-v0.8.0.md) · [release evidence](../reports/v0.8.0-release-verification.md)
