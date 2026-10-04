# NotchMuse Current Handoff

## Current status

NotchMuse **v0.8.0 Build 47 is released**. Its GitHub asset, official signed update feed, website download, and installed Stable app were verified. The authorized media showcase refresh runs on `codex/media-showcase-refresh` from `84bb0c1`; it does not change the app or publish a new version.

## Current architecture

The macOS app lives in `MenuBarLyrics/`. Spotify and Apple Music have player adapters; NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. `LyricsClient` tries ordered lyric providers and `TrackMatcher` conservatively validates matches. Production matcher thresholds and provider priority are frozen. Sparkle 2 uses a signed official feed; Preview uses separate identity and never enters that feed.

## Open work

Media showcase implementation and validation are complete on `codex/media-showcase-refresh`. The three silent demos, EN/ZH README, Hero mode tabs and Appearance section are ready for PM review. Desktop/mobile, reduced motion, loading/fallbacks and static export pass. Pending: Product Owner visual acceptance and PM-controlled merge/deployment. Evidence: [media refresh report](../reports/media/media-showcase-refresh.md). No engineering blocker; website source is `website/`. Broader clean-Mac evidence, Developer ID/notarization, and features remain separate work. Menu Bar Space is paused and archived, not part of Stable.

## References

- **Start here:** [Master handoff](NOTCHMUSE_MASTER_HANDOFF.md)
- [Current status](PROJECT_STATUS.md) · [Task board](TASK_BOARD.md) · [Thread registry](THREAD_REGISTRY.md) · [Roadmap](ROADMAP.md)
- [Pre-cleanup detailed handoff](../archive/PROJECT_HANDOFF-through-v0.8.0.md) · [release evidence](../reports/v0.8.0-release-verification.md)
