# NotchMuse Project Status

## v0.8.2 / Build70 — publication ready, 2026-11-10

- Owner accepted Preview69 and requested source synchronization. Public main now contains `443ac5afb68d091cc154cdc5675bccea9bc37709`; [complete CI](https://github.com/Xiye88/NotchMuse/actions/runs/42741888196) passed, including Swift package tests and release/DMG checks. Twelve English labels were made explicit with values identical to their former fallback; lyric logic is unchanged from acceptance.
- Stable0.8.2/70 candidate is built and verified: signature, read-only DMG mount, 118 bundle file/link matches, Applications shortcut, mounted app self-test and all six uploaded draft asset digests. DMG SHA256: `f0aef83093c7bd0845816f4a52986d8cd3dee1d9c2381145e53c6fdd8226540c`.
- GitHub v0.8.2 is a draft, not publicly downloadable; no v0.8.2 Git tag exists yet. Website/README version changes are local and browser-tested (12 pages, download routing, consent and analytics), not deployed or pushed.
- Final public-release/download promotion is pending the separate Product Owner decision required by AGENTS.md. This will be a manual-install release; official automatic feed stays47. Bilingual lyrics are deferred.

## v0.8.2 / Build70 — release preparation, 2026-11-10

- Product Owner accepted Preview69 listening/synchronization and requested this update; bilingual lyrics remain deferred.
- Public-source integration is based on latest main `2a63580`, exporting only accepted app/test/scripts changes. Runtime and packaging inputs match accepted Preview69; provenance is in [v0.8.2](../releases/v0.8.2/SOURCE_PROVENANCE.json). Current website SEO tree is preserved.
- Related offline timing/selection/provider/recovery/diagnostics and update-feedback checks pass. Stable0.8.2/70 package preparation is in progress. Complete local XCTest remains unavailable in the current Command Line Tools environment; CI status will be recorded separately.
- Public download and website promotion require the final publication confirmation separately from source synchronization. The official automatic-update feed stays at the last qualified Build47; this candidate is for manual installation.

## Current release — 2026-10-18

- **v0.8.1 / Build61 is PUBLIC / RELEASED**, for manual download and installation. [Release](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1) · [Website](https://notchmuse.com) · [Completion report](V081_PUBLIC_RELEASE_COMPLETION.md).
- Annotated tag `v0.8.1` targets public source `8320271b4218431b66175bf40e203230ce8fa741`. The frozen DMG was built at `4c392efbd8da0c8abb0fdc70833575192e18d7d1`; 79 runtime/packaging inputs are byte-identical in the public release. [Provenance](../releases/v0.8.1/SOURCE_PROVENANCE.json).
- Public DMG SHA256: `d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851` (6,802,591 bytes). The website's 12 EN/ZH pages and all36 download CTAs point to this asset; SEO, GA4 consent and CSP are preserved.
- **Sparkle v0.8.1: NOT COMPLETED / not pushed.** Archive signature and tamper rejection passed, but real isolated Build47→61 installer/relaunch/recovery remains unverified. Official feed and its notes stay at Build47. Do not silently activate Build61.
- Local Stable47 and regular Preview60, including preferences, remain unchanged. Stable47 full rollback and v0.8.0 public assets remain available. Only the two existing resident Apps are retained.
- Developer ID/notarization and independent clean-Mac first-install tests are explicitly accepted limitations for this release. First-install/Gatekeeper/permission tests remain **NOT_TESTED**, not PASS. `PAUSED_BY_OWNER` has been explicitly lifted; do not reopen those waived gates or request an account switch.
- Lyrics algorithm remains frozen. Product Owner-accepted APT./Rubia are regression samples, not repeated manual QA tasks. No paid provider, Gateway, membership or new lyric source is included.

## Earlier checkpoints (historical; current release above supersedes them)


Last reviewed: 2026-10-17. [Master handoff](NOTCHMUSE_MASTER_HANDOFF.md) is the project entry point; older checkpoints are in [the archive](../archive/).

## Current

- Public: **v0.8.0, Build 47, RELEASED**. GitHub Release, signed official Sparkle feed, website download, and installed Stable app were verified in [release evidence](../reports/v0.8.0-release-verification.md).
- Stable: `/Applications/NotchMuse.app`. Isolated, non-public development app: `/Applications/NotchMuse Preview.app`.
- Media Showcase Round 2: **ACCEPTED / MERGED / DEPLOYED**. Product Owner accepted the current visuals and explicitly authorized closure. Source `8f4fb378e54c658246757a336810394d332efbd3` is on GitHub main and the feature branch; official site deployment `20261004-media-8f4fb37` is verified. [Closure evidence](../reports/media/media-showcase-production-closure.md).
- No active App feature or release work. Menu Bar Space is experimental, paused, archived, and absent from Stable.
- The repository cleanup is complete. The active media correction creates no App version or release.

## Blockers and next

- No blocker for the already-published v0.8.0.
- Media task complete; EN/ZH GitHub main READMEs load all six media classes. Feature and promoted main CI PASS. Current source-footage limitation and prior pause-control P2 are accepted/deferred for this version; no further media/page work is authorized by this closure.
- Clean-Mac feedback, Developer ID/notarization and future App features remain separate tasks.
- Current `00_PM` has adopted the master handoff; the former long PM remains ready for archival.

## Website publication — 2026-10-17

Responsibility `06_DOCS`, existing SEO chat `01a116ce-e921-70c3-ad28-40baf9e371ed`: **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**. Authorized source `983729a4c9e69a748c5772dcdbefc772b2f582c1` was pushed directly atop main; source CI PASS. Five distinct topics in English and Chinese (10 new URLs), home guide cards and12 sitemap URLs are live in `/opt/notchmuse-site/releases/20261017-seo-983729a`. All44 origin files match; public pages on apex/www match source. Three video transfer timeouts passed complete-hash rechecks. Local preview remains open; in-app public navigation failed with a connection error and is not counted as visual verification. Official appcast/notes preserved byte-for-byte; public App remains v0.8.0 Build47. No confirmation remains for this task. [Closure and evidence](../reports/website/seo-pages-production-2026-10-17.md).
