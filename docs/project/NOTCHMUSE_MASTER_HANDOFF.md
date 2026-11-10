# NotchMuse — Master Project Handoff

## v0.8.2 / Build70 — RELEASED / WEBSITE DEPLOYED, 2026-11-10

- Owner accepted Preview69 and approved publication. [GitHub v0.8.2](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.2) is the regular Latest release. Tag and website deployment source: `0e98ad09e093e61cea4686acbb369154446fbc0a`; [CI passed](https://github.com/Xiye88/NotchMuse/actions/runs/42745321470). Anonymous DMG download matched the frozen SHA256 `f0aef83093c7bd0845816f4a52986d8cd3dee1d9c2381145e53c6fdd8226540c` (7,270,643 bytes).
- Official website serves the GitHub website tree `1bdc6ca03838353d7226b4f93ba1839239186a9a` from `/opt/notchmuse-site/releases/20261110-v082-0e98ad0`. Origin: 48 exact file hashes with preserved CSP. Public apex/www: 36 exact HTTP checks, including 12 pages on each domain with 3 Build70 download links per page. Existing appcast, v0.8.0 notes and v0.8.1 notes preserved byte-for-byte. No DNS or Tunnel changes.
- Manual installation only; automatic update feed remains Build47. Local Stable61 and Preview69 were not replaced. Bilingual lyrics remain deferred. [Delivery record](../reports/release/V082_PUBLICATION_COMPLETION.md).

## Historical checkpoint: app published, website pending — 2026-11-10

- Product Owner explicitly approved publication. [GitHub v0.8.2](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.2) is a regular Latest release; annotated tag and public source point to `0e98ad09e093e61cea4686acbb369154446fbc0a`. Corresponding [tag CI](https://github.com/Xiye88/NotchMuse/actions/runs/42744796915) passed.
- Anonymous official DMG download returned HTTP200, 7,270,643 bytes, exact frozen SHA256 `f0aef83093c7bd0845816f4a52986d8cd3dee1d9c2381145e53c6fdd8226540c`. Source main/README/website download code are synchronized. This is a manual-install release; no automatic feed promotion or local Stable replacement occurred.
- Actual website server deployment is not complete. The old temporary connection entry is unavailable, and the bounded existing-record search found no reusable connection helper. A user question requests only the existing deployment tool/configuration location, not a password/private key in chat. No further release approval is needed.
- The verified44-file website/notes bundle is ready for the existing server layout; retain current feed and old notes/rollback when connection is restored. Do not rebuild or republish the DMG.

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

## Current release — 2026-10-18

- **v0.8.1 / Build61 is PUBLIC / RELEASED**, for manual download and installation. [Release](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.1) · [Website](https://notchmuse.com) · [Completion report](V081_PUBLIC_RELEASE_COMPLETION.md).
- Annotated tag `v0.8.1` targets public source `8320271b4218431b66175bf40e203230ce8fa741`. The frozen DMG was built at `4c392efbd8da0c8abb0fdc70833575192e18d7d1`; 79 runtime/packaging inputs are byte-identical in the public release. [Provenance](../releases/v0.8.1/SOURCE_PROVENANCE.json).
- Public DMG SHA256: `d8e2bc73e22cc79919708b88539edf480b7c07f14fe67d1d9683c9d530f77851` (6,802,591 bytes). The website's 12 EN/ZH pages and all36 download CTAs point to this asset; SEO, GA4 consent and CSP are preserved.
- **Sparkle v0.8.1: NOT COMPLETED / not pushed.** Archive signature and tamper rejection passed, but real isolated Build47→61 installer/relaunch/recovery remains unverified. Official feed and its notes stay at Build47. Do not silently activate Build61.
- Local Stable47 and regular Preview60, including preferences, remain unchanged. Stable47 full rollback and v0.8.0 public assets remain available. Only the two existing resident Apps are retained.
- Developer ID/notarization and independent clean-Mac first-install tests are explicitly accepted limitations for this release. First-install/Gatekeeper/permission tests remain **NOT_TESTED**, not PASS. `PAUSED_BY_OWNER` has been explicitly lifted; do not reopen those waived gates or request an account switch.
- Lyrics algorithm remains frozen. Product Owner-accepted APT./Rubia are regression samples, not repeated manual QA tasks. No paid provider, Gateway, membership or new lyric source is included.

## Earlier checkpoints (historical; current release above supersedes them)


Last reviewed: 2026-10-17. This is the first entry point for a new `00_PM`. For live task state use [PROJECT_STATUS](PROJECT_STATUS.md), [TASK_BOARD](TASK_BOARD.md), and [THREAD_REGISTRY](THREAD_REGISTRY.md); archived documents are historical evidence, not competing current status.

## 1. Identity and product

| Item | Current state |
| --- | --- |
| Project | NotchMuse |
| Repository | https://github.com/Xiye88/NotchMuse |
| Website | https://notchmuse.com |
| Public version / build | **v0.8.0 / 47** |
| Release state | **RELEASED**; regular GitHub Release `v0.8.0` |
| Platform | macOS 14+, Apple Silicon; Intel is not supported |
| Public runtime source | `15e13fc2c23ff8f5530db7e5629de076dd9011c5` |

NotchMuse displays synchronized lyrics without requiring a separate browser or an account. The core value is readable, low-friction lyrics beside the Mac notch, in the status bar, at a screen side, or above the Dock while music plays. The public README is deliberately short and user-facing. The product does not upload audio or collect telemetry; it sends track metadata to lyric sources when matching is needed.

## 2. Current supported players and playback architecture

- **Spotify**: dedicated adapter/reader with macOS Automation access where requested.
- **Apple Music**: dedicated Apple Music adapter with macOS Automation access where requested.
- **NetEase Cloud Music**: NetEase adapter using the bundled MediaRemote bridge.
- **QQ Music and Soda Music**: shared MediaRemote player adapter and the same bundled bridge.
- **Auto Detect** is the default; explicit player selection remains available. The player-selection layer owns which adapter's snapshot drives lyrics. It must clear stale ownership/track state on changes, pauses, exits, and restarts.
- Source: `MenuBarLyrics/Sources/MenuBarLyrics/Players/`; app lifecycle in `App/`; lyric state and rendering in `Lyrics/` and `UI/`. The bridge ships with the app; users do not install Homebrew or a helper separately.

## 3. Lyrics architecture and frozen behavior

`LyricsClient` tries sources in this current code order: **LRCLIB → NetEase → LRCMux → QQ → Kugou → Soda**. Cached results retain selected-provider metadata. `TrackMatcher` compares normalized title/artist/album/duration, rejects weak or ambiguous candidates, and favors no lyrics over wrong lyrics. Engineering benchmarks are diagnostic evidence, not a guarantee for any individual song.

Production matcher thresholds, ranking, provider priority, and the accepted player lifecycle are **frozen**. Do not reorder a source or relax matching because of a single failed song. The separate `tools/lyrics-provider-benchmark/` is an executable lab with datasets and tests; its reports live under `docs/reports/`. Historical matcher and provider experiments are complete until a new evidence-backed task is approved.

## 4. Shipped v0.8.0 UI

- Status Bar lyrics; Notch Mode; side lyrics; lyrics above the Dock.
- Display width, position/horizontal offset and anchored positions; appearance, backgrounds, opacity, solid and gradient presets, custom lyric colors.
- System/Light/Dark appearance, English/Simplified Chinese, Auto Detect and manual player choice.
- Launch at Login, Dock visibility, menu bar icon visibility, Settings, Support NotchMuse, and in-app update controls.
- Both-hidden Dock/menu recovery, overlay click-through, paused/stopped lyric behavior, and long-line scrolling were addressed before the accepted Build 47. Preserve these behaviors in future regressions.

## 5. Stable, Preview, versions and release boundary

- `/Applications/NotchMuse.app` is the **public Stable** installation. `/Applications/NotchMuse Preview.app` is the isolated, local-only development app with its own bundle identity and preferences.
- Every new feature/fix goes to Preview first. Product Owner acceptance precedes merge to `main` and a new release decision. Preview is never a public GitHub Release and never enters the official feed.
- Public versions advance as `v0.8.0`, `v0.8.1`, `v0.8.2`, `v0.9.0`, then `v1.0.0` when warranted. Do not publish a Preview/Beta/prerelease or four-part `0.8.0.1` as the next stable version. Historical Beta tags remain preserved.
- This repository-cleanup commit is documentation-only: **no build bump, tag, Release, DMG replacement, official appcast edit, or website download switch**.

## 6. Sparkle 2 and release workflow

Sparkle 2 verifies update artifacts with EdDSA. The official stable feed is `https://notchmuse.com/appcast.xml`; release notes are English-first with Chinese content for both audiences. Preview updates use an isolated non-public staging feed only. Beta 3 and older builds lack Sparkle and require one manual installation of v0.8.0 or later.

The EdDSA **private key is not in the repository**. Keep it in the macOS Keychain or a protected release environment; only the public key is embedded in the app. Never place keys or secrets in handoff documents. Stable builds are currently ad-hoc signed, not Developer-ID notarized; Gatekeeper guidance is in public support docs.

Release sequence: **Preview → Product Owner PASS → preflight and artifact verification → merge main → main CI PASS → tag → regular GitHub Release with DMG/SHA256/build info → signed official appcast → website latest/download → public URL and downloaded-byte verification**. Do not activate a feed before the matching asset exists, and do not rewrite a published signed asset in place. See [release policy](RELEASE_POLICY.md), [release preparation](UPDATE_RELEASE_AUTOMATION.md), [release checklist](RELEASE_CHECKLIST.md), and [v0.8.0 evidence](../reports/v0.8.0-release-verification.md).

## 7. Website and public repository

Website source is `website/` in this repository; the public apex and www point to the verified v0.8.0 download. Public docs explain DMG installation and the Gatekeeper **Open Anyway** flow without asking users to disable system-wide security. `README.md` and `README.zh-CN.md` are the public front door; this cleanup changes only links caused by moved documents.

Media Showcase Round 2 is **accepted, merged and deployed**. Source
`8f4fb378e54c658246757a336810394d332efbd3` is on main and
`codex/media-showcase-refresh`; full-desktop videos/GIFs replace the rejected
narrow crops. Production directory `/opt/notchmuse-site/releases/20261004-media-8f4fb37`
is served by the existing VPS static service through Cloudflare Tunnel; this is
a manual deployment from main, not automatic deployment on push. EN/ZH GitHub
main READMEs and apex/www website are verified. Product Owner accepted current
footage/visuals and authorized closure without further page/media changes; the
physical-cutout limitation and prior pause-control P2 are recorded as accepted/deferred.
[Closure evidence](../reports/media/media-showcase-production-closure.md).
App v0.8.0/Build 47, downloads and official feed remain unchanged.

Root should now be primarily `.github/`, `LICENSES/`, `MenuBarLyrics/`, `docs/`, `scripts/`, `tools/`, `website/`, and the public/legal/build files: `.gitignore`, `AGENTS.md`, `CHANGELOG.md`, `LICENSE`, `README.md`, `README.zh-CN.md`, `THIRD_PARTY_NOTICES.md`. Tiny root `SUPPORT.md` and `FEEDBACK.md` compatibility links remain so existing public URLs keep working; their **only editable source** is `docs/community/`. `docs/project/` contains the single canonical PM documents; `docs/releases/`, `docs/reports/`, and `docs/archive/` contain releases, evidence, and old snapshots. Build artifacts under `dist*.noindex/` are local, untracked, and not part of the public root.

## 8. Support and donation

The app's Support page and [public support guide](../community/SUPPORT.md) cover WeChat Pay, USDT on EVM networks (Ethereum, BSC/BEP20, Arbitrum, Optimism), TRON/TRC20, and supporters who consent to credit. Public addresses are **EVM `0x6c0275e975818e99d078ee2348576e2d9608f6d6`** and **TRON `TCTrNcvTD3QE7opC61mKoTyUmRkKos6jan`**. There are no private keys in these docs. Network selection must be explicit to donors.

## 9. Menu Bar Space experiment

**EXPERIMENTAL / PAUSED / ARCHIVED. Not in the public product.** The preserved remote branch is `origin/codex/menu-bar-space` at `62b47067a601fb48a6292efdfcee10e8c92d4036`, with `MENU_BAR_SPACE_HANDOFF.md` on that branch. Native movement/hiding of menu bar icons added macOS-level complexity disproportionate to current value. Do not merge or restart it without a new product decision; future help could mention a separate menu bar utility instead.

## 10. Regression memory — do not reopen resolved bugs casually

Accepted releases already addressed NetEase seek, pause/resume, restart, stale lyrics, Auto Detect owner transitions, quick Apple Music/Spotify/QQ/Soda transitions, long lyric scrolling, overlay click-through, pause-hide behavior, notch background, custom colors, window sizing, app reopen, Dock/menu visibility, and Sparkle staged install/relaunch. Preserve these in future focused regression tests. Detailed historical evidence is under `docs/reports/` and `docs/archive/`; do not convert old pending checkpoints into current blockers.

## 11. Real backlog and technical debt

- Media refresh is complete on main and in production, with Product Owner acceptance recorded above. Wider real-user/clean-Mac feedback remains optional; neither blocks the released v0.8.0.
- Developer ID signing, notarization and stapling are not configured; ad-hoc signing creates first-launch Gatekeeper friction. This needs a distinct distribution decision.
- Intel/Universal Binary and native Player Lyrics fallback are not shipped. MediaRemote is a private-framework compatibility risk; re-test against future macOS/player updates when evidence warrants it.
- Local `swift test` has historically lacked XCTest under the selected Command Line Tools; CI/macOS builds and packaged self-tests supplied release evidence. Recheck the toolchain rather than treating old status text as a current failure.
- Do **not** resume Menu Bar Space, conduct a major Matcher rewrite, change provider priority casually, or run an unnecessary long soak. No additional public release is planned by this handoff.

## 12. PM operating rules and current threads

`00_PM` coordinates work and owns the canonical docs. Reuse `01_APP` through `07_QA` responsibilities; do not create duplicate numbered threads. Subtasks must report results back to PM. On major implementation, release, architecture change, thread archival, or product-policy change, update this master handoff, [status](PROJECT_STATUS.md), [board](TASK_BOARD.md), and [registry](THREAD_REGISTRY.md). Keep routine PM prompts Chinese. Do not repeatedly request approval for ordinary reversible work; public release decisions remain explicit. Long soak is best validated by the Product Owner's actual use, not by speculative repeated tests.

Current `00_PM` `01a104b8-1eb0-7320-8706-29eece12ab9f` has adopted this handoff
and is handling the authorized media correction. The former long `00_PM`
`019f741e-4308-7360-82f8-4e5c0d1c9224` remains ready to archive. `01_APP`–`07_QA`
finished the v0.8.0 release; `06_DOCS` now tracks the media work. Menu Bar Space
is archived. Preserve historical IDs in [the old registry](../archive/THREAD_REGISTRY-through-v0.8.0.md);
do not create another duplicate PM.

## NEW PM START HERE

1. Read root `AGENTS.md`.
2. Read this file and [current status](PROJECT_STATUS.md); scan [task board](TASK_BOARD.md) and [thread registry](THREAD_REGISTRY.md).
3. `git fetch origin`, compare `main` and the latest regular Release without altering Stable or Preview apps.
4. Read a specific archived report or source file only for the next concrete question. Do **not** replay hundreds of prior chat messages.
5. Continue only the newly authorized phase. Keep version/feed/release boundaries explicit and update canonical documents after material changes.

## Website publication — 2026-10-17

Responsibility `06_DOCS`, existing SEO chat `01a116ce-e921-70c3-ad28-40baf9e371ed`: **SYNCHRONIZED / DEPLOYED / PUBLIC HTTP VERIFIED**. Authorized source `983729a4c9e69a748c5772dcdbefc772b2f582c1` was pushed directly atop main; source CI PASS. Five distinct topics in English and Chinese (10 new URLs), home guide cards and12 sitemap URLs are live in `/opt/notchmuse-site/releases/20261017-seo-983729a`. All44 origin files match; public pages on apex/www match source. Three video transfer timeouts passed complete-hash rechecks. Local preview remains open; in-app public navigation failed with a connection error and is not counted as visual verification. Official appcast/notes preserved byte-for-byte; public App remains v0.8.0 Build47. No confirmation remains for this task. [Closure and evidence](../reports/website/seo-pages-production-2026-10-17.md).
