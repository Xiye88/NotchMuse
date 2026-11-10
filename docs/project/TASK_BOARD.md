# NotchMuse Task Board

## v0.8.2 / Build70 — PUBLICATION_AUTHORIZED, 2026-11-10

Owner explicitly approved publication after reviewing the ready package. Publishing the frozen manual-install release and promoting the verified README/website0.8.2 download links. Runtime and package inputs remain unchanged from the verified build source443ac5a except release documents outside the build inputs. Public artifact/site verification is in progress; completion will be recorded after deployment. Official automatic feed47 stays unchanged; bilingual lyrics remain deferred.

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

## Website three SEO fixes — 2026-11-04 (DEPLOYED)

GitHub main integrated source `9d1d50e79698d989b1bf80d53a49e19e93f7440b`; website tree `82d8ede83750e2ff111c3a8e3f8ceb1e7404fc1d`. Production `/opt/notchmuse-site/releases/20261104-seo-9d1d50e`:42GitHub static files+4retained feed/notes,46origin hashes/CSP PASS;72public requests exact-match PASS (66local,6media from production host via public Cloudflare HTTPS).12page schema/SEO/download protection PASS;public browser3/4PASS, remaining limits and original failures in report. App CI completed failure (job cancelled,no runner/steps), not PASS; unrelated App queue gate removed by PM, main rules=[]. Old release/server rollback retained. No App/Release/feed changes. Documentation-only follow-up preserves website tree; no redeploy. [Report](../reports/website/seo-3-fixes-2026-11-04.md).

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
