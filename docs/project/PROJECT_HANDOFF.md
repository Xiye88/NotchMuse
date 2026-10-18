# NotchMuse Current Handoff

## Active release checkpoint — 2026-10-18

Product Owner has explicitly lifted `PAUSED_BY_OWNER` and authorized the public **v0.8.1 / Build61** release, Git push/tag, GitHub assets and the necessary website deployment. Developer ID/notarization and independent clean-Mac testing are accepted limitations for this release, not pending approvals. No such test is reported as PASS.

The frozen DMG remains unchanged (SHA256 `d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851`). Integrate the frozen Build61 runtime/build inputs atop current public main, preserving all SEO/analytics work. Publish only reviewed source and public release materials, never the private development history or test data. Installed Stable47 and Preview60 remain untouched.

Sparkle is a separate gate: cryptographic validation alone does not qualify actual updater installation/relaunch/recovery. If actual isolated Build47→61 verification cannot be completed safely, publish manual downloads while retaining the Build47 official feed.

```text
Current status: v0.8.1 FINAL AUTHORIZATION / public release in progress.
Completed: Frozen artifact hash; website reconciliation with current main; release source isolation.
Pending confirmation: None for the authorized publication; no account or credential purchase.
Key files: docs/project/PROJECT_HANDOFF.md; docs/releases/v0.8.1/; website/.
Next step: Verify staged source/materials, publish GitHub assets and website, verify actual public bytes.
Do not repeat: Lyrics algorithm work, accepted-song manual QA, source research, or waived installation gates.
```

## Earlier public checkpoints (historical)

## Current status

NotchMuse **v0.8.0 Build 47 is released**. Its GitHub asset, official signed update feed, website download, and installed Stable app were verified. Media Showcase Round 2 is accepted, pushed, merged to main and deployed from source `8f4fb37`; it does not change the app or publish a new version.

## Current architecture

The macOS app lives in `MenuBarLyrics/`. Spotify and Apple Music have player adapters; NetEase, QQ Music, and Soda Music use the bundled MediaRemote bridge. `LyricsClient` tries ordered lyric providers and `TrackMatcher` conservatively validates matches. Production matcher thresholds and provider priority are frozen. Sparkle 2 uses a signed official feed; Preview uses separate identity and never enters that feed.

## Open work

README follow-up: Product Owner requested default-collapsed sponsorship details in both languages. Implemented native GitHub details/summary around the QR codes and support text; original contents preserved. GitHub GFM rendering verifies a closed disclosure and all three QR images/table retained. This small correction is synchronized to main; no website deployment is needed.

```text
Current status: README sponsorship defaults to collapsed in EN/ZH.
Completed: Native disclosure markup; original content preserved; GitHub GFM checks.
Pending confirmation: None for this README correction.
Key files: /Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/README.md;
/Users/carlos/Documents/歌词/.worktrees/v08-main-integration-20260926/README.zh-CN.md.
Next step: Stop after public GitHub closed/open smoke verification.
Do not repeat: Media creation, website deployment or App release work.
```

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

## Website publication — 2026-10-17

Responsibility `06_DOCS`, existing SEO chat `01a116ce-e921-70c3-ad28-40baf9e371ed`: **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**. Authorized source `983729a4c9e69a748c5772dcdbefc772b2f582c1` was pushed directly atop main; source CI PASS. Five distinct topics in English and Chinese (10 new URLs), home guide cards and12 sitemap URLs are live in `/opt/notchmuse-site/releases/20261017-seo-983729a`. All44 origin files match; public pages on apex/www match source. Three video transfer timeouts passed complete-hash rechecks. Local preview remains open; in-app public navigation failed with a connection error and is not counted as visual verification. Official appcast/notes preserved byte-for-byte; public App remains v0.8.0 Build47. No confirmation remains for this task. [Closure and evidence](../reports/website/seo-pages-production-2026-10-17.md).
