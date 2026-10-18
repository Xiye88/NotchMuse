# NotchMuse Task Board

## Current release — 2026-10-18

- **v0.8.1 / Build61 is PUBLIC / RELEASED**, for manual download and installation. [Release](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1) · [Website](https://notchmuse.com) · [Completion report](V081_PUBLIC_RELEASE_COMPLETION.md).
- Annotated tag `v0.8.1` targets public source `8320271b4218431b66175bf40e203230ce8fa741`. The frozen DMG was built at `4c392efbd8da0c8abb0fdc70833575192e18d7d1`; 79 runtime/packaging inputs are byte-identical in the public release. [Provenance](../releases/v0.8.1/SOURCE_PROVENANCE.json).
- Public DMG SHA256: `d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851` (6,802,591 bytes). The website's 12 EN/ZH pages and all36 download CTAs point to this asset; SEO, GA4 consent and CSP are preserved.
- **Sparkle v0.8.1: NOT COMPLETED / not pushed.** Archive signature and tamper rejection passed, but real isolated Build47→61 installer/relaunch/recovery remains unverified. Official feed and its notes stay at Build47. Do not silently activate Build61.
- Local Stable47 and regular Preview60, including preferences, remain unchanged. Stable47 full rollback and v0.8.0 public assets remain available. Only the two existing resident Apps are retained.
- Developer ID/notarization and independent clean-Mac first-install tests are explicitly accepted limitations for this release. First-install/Gatekeeper/permission tests remain **NOT_TESTED**, not PASS. `PAUSED_BY_OWNER` has been explicitly lifted; do not reopen those waived gates or request an account switch.
- Lyrics algorithm remains frozen. Product Owner-accepted APT./Rubia are regression samples, not repeated manual QA tasks. No paid provider, Gateway, membership or new lyric source is included.

## Current task disposition

| Work | State | Next action |
| --- | --- | --- |
| Build61 source, tag, GitHub assets, EN/ZH README/notes, CHANGELOG | DONE / PUBLIC | Keep published artifact immutable. |
| Website download/version update; preserve growth infrastructure | DONE / DEPLOYED | Monitor actual user reports; no redesign. |
| v0.8.1 Sparkle installer qualification | NOT COMPLETED / MANUAL UPDATE | Separate bounded updater task when a safe isolated session is available; no feed change now. |
| Developer ID / notarization / independent clean-Mac test | DEFERRED / ACCEPTED LIMITATIONS | Do not repeatedly request these for v0.8.1. |
| Lyrics matching and accepted-song manual QA | FROZEN | Only reproduce common regressions with evidence; no single-song development loop. |

## Earlier checkpoints (historical; current release above supersedes them)


Last reviewed: 2026-10-17. Detailed historical checklists are [archived](../archive/TASK_BOARD-through-v0.8.0.md).

## Active

None. Media Showcase closure is complete; no App development or release task is active.

## Recently completed

- README sponsorship: English/Chinese QR codes and support text placed in a native GitHub disclosure, closed by default; GitHub GFM rendering and original-content preservation verified.

- Media Showcase Round 2: Product Owner accepted the current visuals; `8f4fb37` pushed to feature and fast-forwarded/pushed to main; feature/main CI PASS; production `20261004-media-8f4fb37` verified. EN/ZH READMEs load Hero poster, Status Bar/Notch/Appearance GIFs and both Settings screenshots. [Evidence](../reports/media/media-showcase-production-closure.md).

- v0.8.0 Build 47: Product Owner accepted Preview; regular GitHub Release, public DMG, signed official appcast, website download, installed Stable, and verification evidence completed.
- Stable and Preview remain isolated. Historical release notes and QA evidence are retained.

## Backlog — start only as a new task

- Real-user feedback; any future physical-notch footage or pause-control work requires a new task. Current visuals are accepted and retained.
- Developer ID signing/notarization and wider clean-Mac testing.
- Native Player Lyrics fallback, Intel support, or new players only after separate product/technical review.
- Menu Bar Space: **PAUSED / ARCHIVED**; not a Stable feature.

## Website publication — 2026-10-17

Responsibility `06_DOCS`, existing SEO chat `01a116ce-e921-70c3-ad28-40baf9e371ed`: **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**. Authorized source `983729a4c9e69a748c5772dcdbefc772b2f582c1` was pushed directly atop main; source CI PASS. Five distinct topics in English and Chinese (10 new URLs), home guide cards and12 sitemap URLs are live in `/opt/notchmuse-site/releases/20261017-seo-983729a`. All44 origin files match; public pages on apex/www match source. Three video transfer timeouts passed complete-hash rechecks. Local preview remains open; in-app public navigation failed with a connection error and is not counted as visual verification. Official appcast/notes preserved byte-for-byte; public App remains v0.8.0 Build47. No confirmation remains for this task. [Closure and evidence](../reports/website/seo-pages-production-2026-10-17.md).
