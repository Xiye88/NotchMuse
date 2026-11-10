# NotchMuse Current Handoff

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
