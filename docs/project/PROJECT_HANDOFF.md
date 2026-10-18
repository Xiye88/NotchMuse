# NotchMuse Current Handoff

## Current release — 2026-10-18

- **v0.8.1 / Build61 is PUBLIC / RELEASED**, for manual download and installation. [Release](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1) · [Website](https://notchmuse.com) · [Completion report](V081_PUBLIC_RELEASE_COMPLETION.md).
- Annotated tag `v0.8.1` targets public source `8320271b4218431b66175bf40e203230ce8fa741`. The frozen DMG was built at `4c392efbd8da0c8abb0fdc70833575192e18d7d1`; 79 runtime/packaging inputs are byte-identical in the public release. [Provenance](../releases/v0.8.1/SOURCE_PROVENANCE.json).
- Public DMG SHA256: `d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851` (6,802,591 bytes). The website's 12 EN/ZH pages and all36 download CTAs point to this asset; SEO, GA4 consent and CSP are preserved.
- **Sparkle v0.8.1: NOT COMPLETED / not pushed.** Archive signature and tamper rejection passed, but real isolated Build47→61 installer/relaunch/recovery remains unverified. Official feed and its notes stay at Build47. Do not silently activate Build61.
- Local Stable47 and regular Preview60, including preferences, remain unchanged. Stable47 full rollback and v0.8.0 public assets remain available. Only the two existing resident Apps are retained.
- Developer ID/notarization and independent clean-Mac first-install tests are explicitly accepted limitations for this release. First-install/Gatekeeper/permission tests remain **NOT_TESTED**, not PASS. `PAUSED_BY_OWNER` has been explicitly lifted; do not reopen those waived gates or request an account switch.
- Lyrics algorithm remains frozen. Product Owner-accepted APT./Rubia are regression samples, not repeated manual QA tasks. No paid provider, Gateway, membership or new lyric source is included.

```text
Current status: v0.8.1 / Build61 PUBLIC / WEBSITE DEPLOYED; manual update.
Completed: Sanitized source/main/tag; frozen asset upload and public SHA256; EN/ZH materials;
12 website pages /36 CTAs; desktop/mobile and consent checks; local App/rollback protection.
Pending confirmation: None for this release. Sparkle installer E2E remains a separate uncompleted item.
Key files: docs/project/V081_PUBLIC_RELEASE_COMPLETION.md; docs/releases/v0.8.1/;
docs/reports/release/v081-public-completion/; website/.
Next step: Stop release execution; collect actual user feedback. Retain all rollback artifacts.
Do not repeat: Waived clean-Mac/signing gates, accepted-song manual QA, source/VPS research,
algorithm changes, or activation of an unqualified Sparkle update.
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
