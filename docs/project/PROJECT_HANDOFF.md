# NotchMuse Current Handoff

## Local Preview updater delivery — 2026-11-12

Local0.8.3 Preview71 passed build/packaged self-tests, no-update quiet startup, visible default-ON independent switches and actual signed loopback71→72 automatic download/install/relaunch (no manual check/install action;72 is a same-runtime test fixture). Installed `/Applications/NotchMuse Preview.app` now shows Build72. Daily timer logged delay/interval86400. Original69 rollback retained; first delivery failed startup verification and successfully rolled back, repeat delivery passed.36 policy/preferences/delegate checks +3 packaging configs and lifecycle tests passed. Full XCTest unavailable in CLT (missing XCTest). Actual24-hour wait, offline UI, corrupted-package installer and long-running prepared-update UI remain untested; do not mark full updater qualification complete. Public0.8.2/70 unchanged. Shared future runtime source is intentional, only Preview packaged/delivered; Preview fixture identity was checked before signing. Evidence: PM preview-updater-20261110/preview-verification.json.

## Release governance maintenance — 2026-11-12

Unified one-authorization rule in AGENTS/RELEASE_POLICY; reusable unchecked RELEASE_CHECKLIST replaces completed0.8.0 checklist (preserved in docs/archive). Execution procedure now uses release parameters and verifies all channels in dependency order. Added scripts/check_release_consistency.py; current0.8.2/70 local and real online checks PASS (12 pages, README/download/JSON-LD, Latest/About/package checksum, apex/www feed/notes). Stale README/site/feed mutations are rejected. About now has a version-free description; old screenshot labels correctly identify historical0.8.0 captures (asset commit9554338), so were retained. No Build70 rebuild or republication. Installer/media/translation/feature correctness and cryptographic verification remain explicit checklist items, not claims made by the lightweight script.

Local Preview71 updater development is separate from this governance synchronization; current formal release remains0.8.2/70. Full local XCTest remains unavailable (Command Line Tools lacks XCTest); standalone tests and Preview verification are recorded separately.

## Active — local Preview updater development, 2026-11-10

Owner explicitly authorizes direct coding and local Preview delivery: startup quiet checks (only new updates notify), independent automatic-update toggle default ON for unset preferences, respect explicit OFF, and checks while long-running. PM selects daily checks via existing Sparkle scheduler. Implementation/test plan: docs/superpowers/plans/2026-11-10-preview-updater.md. Public Stable70, official feed, GitHub release and website remain unchanged; no push/publication authorized for this new candidate. Preserve accepted Preview69 for rollback; next candidate >70.

## Owner decision — next-version updater and permanent notes rule, 2026-11-10

- NEXT_VERSION / NOT_IMPLEMENTED: check for available updates when the app opens, and add a separate user-opted-in automatic-download/install checkbox. Preserve update preferences, signed Stable validation and a usable old app on failure; verify install/relaunch before claiming completion. Current0.8.2 remains scheduled checking plus consented installation.
- PERMANENT: release notes must be equally complete in English and Chinese, with a short opening overview/language cue, English first and full Chinese below. This applies to the actual popup, GitHub and website. Owner accepts current0.8.2 wording unchanged. See [release policy](RELEASE_POLICY.md).
- This turn records requirements locally only; no app implementation, build, feed/site change, GitHub push or new release.

```text
Current status: Owner preferences and next-version updater requirements recorded locally; not implemented.
Completed: Equal-detail bilingual release-note policy; startup-check and opt-in automatic-install backlog.
Pending confirmation: No decision needed for recording; candidate implementation/testing and future public release remain separate.
Key files: docs/project/RELEASE_POLICY.md; docs/project/ROADMAP.md; docs/project/TASK_BOARD.md.
Next step: Use the next-version requirements for a bounded updater candidate; review both languages in the actual popup.
Do not repeat: Current-note rewrite/deploy, current-app/feed changes or claiming these future features are already shipped.
```

## Current — v0.8.2 / Build70 UPDATE DELIVERY LIVE, 2026-11-10

- Owner explicitly requested immediate old-user updates. Official signed appcast now advertises70, using the unchanged public v0.8.2 DMG; apex/www and origin bytes verified. Earlier manual-only checkpoints below are historical and superseded.
- Actual full old-app temporary copies passed47→70 and public61→70 download/install/relaunch (118 bundle entries exact); updated70 reports latest. Automatic61 check found70 without clicking Check for Updates and displayed Later/Install/Skip. Complete original preferences restored and compared; installed Stable61/Preview69 unchanged.
- Automatic checks follow user settings and schedule; users confirm installation. Offline apps/disabled checks and Beta3-or-earlier cannot be guaranteed a notice. No app runtime, build/tag or frozen asset replacement. Bilingual lyrics remain deferred.
- Source42b3d4a is synchronized to GitHub main/release branch; main CI passed. Website/notes deployed:46 current-source origin files exact,12 public apex/www checks exact, CSP preserved. Release script and process now support frozen inputs, versioned notes and required signed public-feed verification. [Evidence and limitations](../reports/release/V082_UPDATE_DELIVERY.md).

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

## v0.8.2 / Build70 preparation — 2026-11-10

Owner accepted Preview69 listening/synchronization and requested pushing this update. Bilingual lyrics are deferred. Preparing a stable manual-download candidate with runtime byte-equivalent to accepted Preview69; preserve current website, private development history, and official Build47 feed. Code synchronization is authorized; public download promotion remains a separate final confirmation under the project release rule.

```text
Current status: RELEASE_PREPARATION; accepted Preview69 source frozen, GitHub sync and stable package preparation in progress.
Completed: Owner acceptance; public main and release-path inspection.
Pending confirmation: Final public release/download promotion after concrete package verification.
Key files: docs/releases/v0.8.2/; docs/project/PROJECT_HANDOFF.md.
Next step: Export accepted runtime on latest public main, verify parity, test, build stable0.8.2/70, synchronize source.
Do not repeat: Bilingual development, song/source research, private-history push, automatic feed activation, or unrelated website changes.
```

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
