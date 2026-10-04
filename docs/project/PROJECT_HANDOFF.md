# NotchMuse Current Handoff

## Current status

NotchMuse **v0.8.0 Build 47 is released**. Its GitHub asset, official signed update feed, website download, and installed Stable app were verified. Media Showcase Round 2 is accepted, pushed, merged to main and deployed from source `8f4fb37`; it does not change the app or publish a new version.

## Current architecture

The macOS app lives in `MenuBarLyrics/`. Spotify and Apple Music have player adapters; NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. `LyricsClient` tries ordered lyric providers and `TrackMatcher` conservatively validates matches. Production matcher thresholds and provider priority are frozen. Sparkle 2 uses a signed official feed; Preview uses separate identity and never enters that feed.

## Open work

No active media task or P0. Product Owner accepted the current website and authorized push/merge/deploy without more media or page changes. The source-footage limitation and prior pause-control P2 are accepted/deferred for this version. Broader clean-Mac evidence, Developer ID/notarization and future App features remain separate work. Menu Bar Space stays paused.

## Closure handoff — 2026-10-04

```text
Current status: Media Showcase ACCEPTED / MERGED / DEPLOYED.
Completed: 8f4fb37 pushed to feature/main; both CI runs PASS; public EN/ZH README
six-media verification; production 20261004-media-8f4fb37; apex/www, Hero playback,
media bytes and unchanged appcast/release notes verified; canonical PM docs synced.
Pending confirmation: None for this task.
Key files: /Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/docs/project/PROJECT_STATUS.md;
/Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/docs/project/TASK_BOARD.md;
/Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/docs/project/THREAD_REGISTRY.md;
/Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/docs/reports/media/media-showcase-production-closure.md.
Next step: Stop this task; use main as the source of truth for future work.
Do not repeat: Media creation, page design, v0.8.0 release, App/provider/matcher changes.
```


## References

- **Start here:** [Master handoff](NOTCHMUSE_MASTER_HANDOFF.md)
- [Current status](PROJECT_STATUS.md) · [Task board](TASK_BOARD.md) · [Thread registry](THREAD_REGISTRY.md) · [Roadmap](ROADMAP.md)
- [Pre-cleanup detailed handoff](../archive/PROJECT_HANDOFF-through-v0.8.0.md) · [release evidence](../reports/v0.8.0-release-verification.md)
