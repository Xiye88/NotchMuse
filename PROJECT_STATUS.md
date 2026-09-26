# NotchMuse Project Status

## Current Public Beta — 2026-09-26

- Public Beta: **v0.8.0-beta.2**, build **31**; published as a prerelease with Product Owner approval.
- Release tag / binary source: `v0.8.0-beta.2` / `c606f185efb114a3d7a1fac78eafc5e925bc9b01`.
- Release: https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.0-beta.2
- Download: https://github.com/Xiye88/NotchMuse/releases/download/v0.8.0-beta.2/NotchMuse.dmg
- DMG SHA-256: `1017d81bc80d15244fef3f3ff1d1988d8430c619ce8394cd4ec3e480c00d3e68`.
- Changes: music-themed installer layout, bilingual first-open guide, Privacy & Security navigation shortcut, pinned CI packaging tooling.
- App runtime source is unchanged from Beta 1; no player, Matcher, or provider priority changes.
- Architecture / signing: arm64, ad-hoc, not notarized; macOS 14+. Shortcut does not bypass Gatekeeper or approve the app.
- Release build, packaged full self-test, signature, DMG integrity, mounted files, public download checksum and attachment filename: PASS.
- Source CI: `36245300979`, PASS. Beta 1 assets preserved.
- Five-player/Settings short smoke and NetEase 7–8 hour stability remain prior Product Owner MANUAL PASS; not newly repeated for this packaging-only release.
- Website: VERIFIED, deployment `20260926-08`; apex/www serve three fixed Beta 2 download links, bilingual first-open guidance, and HTML no-cache headers.
- Remaining risks: cross-macOS/download-quarantine shortcut behavior and clean-device onboarding need broader beta feedback; latest Finder visual capture unavailable through CUA.
- Local installed app was not replaced in this release task; Product Owner controls the download/install test.
- Further sync/publication requires a new explicit approval. Freeze feature/Matcher/provider expansion.

All older candidate/build/pending-release sections below are historical and are superseded by this block.


Last Updated: 2026-09-26 — Player expansion integrated with accepted Settings v2

## Unified Candidate (Current)

- Main `22fb8e8` integrates accepted Settings v2 and player timing fixes.
- Build 28 App/DMG, packaged self-test, signature, and checksum verification PASS.
- Integrated CI `36228752066`: PASS. Build 28 installed and running in
  `/Applications/NotchMuse.app`; executable matches the verified package,
  Preview wallpaper is present. Build 26 is backed up under `dist.noindex/local-backups`.
- Installed Settings GUI interaction is not independently re-tested in this
  integration; Product Owner accepted v2 preview images before integration.
- No tag/public Release; ad-hoc signing only. Records below describe prior candidates.

## Prior Task — Isolated Player + Settings Integration

- Branch: `codex/player-expansion-integration`; latest main `a5f1938` merged
  locally, including accepted Settings Visual Polish v2. No push occurred.
- QQ Music/Soda support and lyric timing fix are retained; no new Settings UI,
  Matcher, or Provider Priority edits were made.
- Candidate build 27 is in `dist.noindex/NotchMuse.app`; executable SHA-256
  `b91b167c0860af7099acaec7f92d8b7cc63ccd5aeb1d70a27f244c012ce7f0f3`.
  Wallpaper resource presence and strict app signature pass. The installed
  `/Applications/NotchMuse.app` remains untouched.
- Debug build, full self-tests, and packaged self-test pass. Local `swift test`
  is blocked because Command Line Tools do not provide XCTest. Integrated-merge
  CI is pending; short visible Settings and timing GUI regression remains open.
- No main push, tag, or publication. Final player handoff awaits acceptance.

## Final Engineering Status

- Settings Visual Polish v2: Product Owner accepted the preview images.
  Production UI source is main `a5f193832dd7889a3ebf25d1087dae867ff68813`;
  CI `36223310974` passed. Build 24 was deployed and verified.
- The installed app is now the separate player sprint's build 26, without
  `SettingsPreviewWallpaper.png`. Unified packaging is pending; do not replace
  it with build 24 or treat build 26 as the accepted Settings artifact.

- `09_REPO_ARCHITECTURE`: DONE / ARCHIVED on
  `codex/repository-architecture-cleanup` at
  `d5673b9b5b9e25baff4abb57db2264f30ace19c2`.
- Remote Architecture branch: synchronized; final CI run `36157250718` PASS.
- Integrated into `main` with merge commit
  `7bc74acd9abe8f6c4b5eb185b3dd5dd51c273ff0`.
- Build source `776437a352d8f81ce6915c4779766f91d3142047` is on
  `origin/main`; latest main CI run `36217972870` PASS.
- Repository structure, Swift package tests, GitHub CI, bilingual README,
  report indexes, and build artifact manifests: DONE.
- Final integrated artifact: `0.8.0` build `21`, arm64, ad-hoc signed,
  not notarized. DMG SHA-256:
  `ea1d037ec22ceb646627b2ecf78104e3ae029395767b6dadc94ef6718727e4b6`.
- The old `/Applications/NotchMuse.app` was build 18. It was replaced with
  build 21 from the verified main SHA; the old bundle remains recoverable at
  `/tmp/NotchMuse-build18-before-settings-20260926.app`.
- `10_SETTINGS_UI`: DONE. The isolated implementation branch ends at
  `5d74ce67ad25dfd9fa1c0a036cc4f06d05772575`; CI run `36213755351` passed.
  The implementation was integrated into main as `279b910` without changing
  player, Matcher, Provider, or release behavior.
- Developer ID/notarization/stapling: DEFERRED. v0.8.0 tag and GitHub Release:
  NOT AUTHORIZED; awaiting a separate Product Owner release decision.

## Current Status

- NetEase: DONE for the v0.8 candidate.
- MediaRemote Bridge: DONE for the v0.8 candidate.
- Auto Detect: DONE for Spotify, Apple Music, and NetEase.
- v0.8 Main Closure: DONE. Build 21 is installed in `/Applications`.
- Product Owner opened the installed build 21 and confirmed the redesigned
  Settings sidebar, Live Preview, card layout, and presets: GUI PASS.
- Final Engineering is integrated into `main`. No v0.8 tag, GitHub Release, or
  public website release has been created.

## Candidate Identity

- Version/build: `0.8.0` build `21`.
- Source commit: `776437a352d8f81ce6915c4779766f91d3142047`.
- Executable SHA-256:
  `cda3bcbf805519e7b9a51c7ecdd90fec76be1b5aa61d00221c483ad3aa51aa13`.
- DMG: `dist.noindex/NotchMuse.dmg`; SHA-256
  `ea1d037ec22ceb646627b2ecf78104e3ae029395767b6dadc94ef6718727e4b6`.
- Architecture: arm64. Signing: ad-hoc, no Team ID. Developer ID signing,
  notarization, and stapling are not included in this candidate.

## Completed Gates

- Debug and Release builds and self-tests: PASS.
- Localization key parity: 102 English / 102 Simplified Chinese, exact parity.
- `git diff --check`: PASS.
- `codesign --verify --deep --strict`: PASS; `hdiutil verify`: PASS.
- Installed build 21 executable is byte-identical to the verified package.
  Installed Settings GUI: Product Owner manual PASS on build 21.
  Installed NetEase short smoke confirmed Auto Detect, Play, Pause/Resume,
  Next/Previous, seek, and visible advancing lyrics. Product Owner reports
  approximately 7-8 hours of prior use as MANUAL PASS.
- Product Owner confirms build 18 seek forward/back, Notch Mode/current and
  restart lyrics, custom color persistence, Hide on Hover, Auto Detect player
  combinations/ownership/fallback/stale clearing, Sleep/Wake, and network
  recovery: Manual PASS. No unprovided steps or latency values are asserted.
- Continuous-playback soak: 60 minutes, PASS for playback and helper stability;
  three checkpoints and multiple advancing playback/track observations, with
  one app, watchdog, and Perl stream process and no crash/restart/orphan.

## Known Risks and Release Review

- The candidate is ad-hoc signed and has no Team ID; Gatekeeper rejects it.
  Developer ID signing, notarization, stapling, and clean-new-user install
  assessment remain release-review/distribution work.
- The manual GUI confirmation was supplied as a consolidated PASS without
  per-step artifacts or exact durations. The closure report preserves that
  evidence level without inventing details.
- `Production Matcher`, thresholds, ranking, and Provider priority remain
  frozen; no changes to them are part of this sprint.

## Historical Evidence

Build 7, 14, 15, 16, 17, and 18 observations are historical for the installed
build 21. Prior backup Git sync and install
snapshots remain in `PROJECT_HANDOFF.md` as historical evidence.
