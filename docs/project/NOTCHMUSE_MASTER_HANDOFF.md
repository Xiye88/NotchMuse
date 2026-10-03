# NotchMuse — Master Project Handoff

Last reviewed: 2026-10-04. This is the first entry point for a new `00_PM`. For live task state use [PROJECT_STATUS](PROJECT_STATUS.md), [TASK_BOARD](TASK_BOARD.md), and [THREAD_REGISTRY](THREAD_REGISTRY.md); archived documents are historical evidence, not competing current status.

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

Root should now be primarily `.github/`, `LICENSES/`, `MenuBarLyrics/`, `docs/`, `scripts/`, `tools/`, `website/`, and the public/legal/build files: `.gitignore`, `AGENTS.md`, `CHANGELOG.md`, `LICENSE`, `README.md`, `README.zh-CN.md`, `THIRD_PARTY_NOTICES.md`. Tiny root `SUPPORT.md` and `FEEDBACK.md` compatibility links remain so existing public URLs keep working; their **only editable source** is `docs/community/`. `docs/project/` contains the single canonical PM documents; `docs/releases/`, `docs/reports/`, and `docs/archive/` contain releases, evidence, and old snapshots. Build artifacts under `dist*.noindex/` are local, untracked, and not part of the public root.

## 8. Support and donation

The app's Support page and [public support guide](../community/SUPPORT.md) cover WeChat Pay, USDT on EVM networks (Ethereum, BSC/BEP20, Arbitrum, Optimism), TRON/TRC20, and supporters who consent to credit. Public addresses are **EVM `0x6c0275e975818e99d078ee2348576e2d9608f6d6`** and **TRON `TCTrNcvTD3QE7opC61mKoTyUmRkKos6jan`**. There are no private keys in these docs. Network selection must be explicit to donors.

## 9. Menu Bar Space experiment

**EXPERIMENTAL / PAUSED / ARCHIVED. Not in the public product.** The preserved remote branch is `origin/codex/menu-bar-space` at `62b47067a601fb48a6292efdfcee10e8c92d4036`, with `MENU_BAR_SPACE_HANDOFF.md` on that branch. Native movement/hiding of menu bar icons added macOS-level complexity disproportionate to current value. Do not merge or restart it without a new product decision; future help could mention a separate menu bar utility instead.

## 10. Regression memory — do not reopen resolved bugs casually

Accepted releases already addressed NetEase seek, pause/resume, restart, stale lyrics, Auto Detect owner transitions, quick Apple Music/Spotify/QQ/Soda transitions, long lyric scrolling, overlay click-through, pause-hide behavior, notch background, custom colors, window sizing, app reopen, Dock/menu visibility, and Sparkle staged install/relaunch. Preserve these in future focused regression tests. Detailed historical evidence is under `docs/reports/` and `docs/archive/`; do not convert old pending checkpoints into current blockers.

## 11. Real backlog and technical debt

- Optional refreshed v0.8.0 screenshots/demo and wider real-user/clean-Mac feedback. These are not blockers to the already-published release.
- Developer ID signing, notarization and stapling are not configured; ad-hoc signing creates first-launch Gatekeeper friction. This needs a distinct distribution decision.
- Intel/Universal Binary and native Player Lyrics fallback are not shipped. MediaRemote is a private-framework compatibility risk; re-test against future macOS/player updates when evidence warrants it.
- Local `swift test` has historically lacked XCTest under the selected Command Line Tools; CI/macOS builds and packaged self-tests supplied release evidence. Recheck the toolchain rather than treating old status text as a current failure.
- Do **not** resume Menu Bar Space, conduct a major Matcher rewrite, change provider priority casually, or run an unnecessary long soak. No additional public release is planned by this handoff.

## 12. PM operating rules and current threads

`00_PM` coordinates work and owns the canonical docs. Reuse `01_APP` through `07_QA` responsibilities; do not create duplicate numbered threads. Subtasks must report results back to PM. On major implementation, release, architecture change, thread archival, or product-policy change, update this master handoff, [status](PROJECT_STATUS.md), [board](TASK_BOARD.md), and [registry](THREAD_REGISTRY.md). Keep routine PM prompts Chinese. Do not repeatedly request approval for ordinary reversible work; public release decisions remain explicit. Long soak is best validated by the Product Owner's actual use, not by speculative repeated tests.

The former long `00_PM` is **handoff/ready to archive**, not a source of new active tasks. `01_APP`–`07_QA` finished the v0.8.0 release; Menu Bar Space is archived. Preserve their history in [the old registry](../archive/THREAD_REGISTRY-through-v0.8.0.md). A new PM should start a fresh `00_PM` only when the Product Owner opens a new phase.

## NEW PM START HERE

1. Read root `AGENTS.md`.
2. Read this file and [current status](PROJECT_STATUS.md); scan [task board](TASK_BOARD.md) and [thread registry](THREAD_REGISTRY.md).
3. `git fetch origin`, compare `main` and the latest regular Release without altering Stable or Preview apps.
4. Read a specific archived report or source file only for the next concrete question. Do **not** replay hundreds of prior chat messages.
5. Continue only the newly authorized phase. Keep version/feed/release boundaries explicit and update canonical documents after material changes.
