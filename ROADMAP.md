# NotchMuse Roadmap

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


Last Updated: 2026-09-26 — QQ Music / Soda Music expansion active

## Current — QQ Music and Soda Music Expansion

Status: IMPLEMENTED / LOCAL CANDIDATE BUILT; QA GATES OPEN

- Add QQ Music and Soda Music to explicit player selection and Auto Detect.
- Reuse the bundled MediaRemote bridge and existing lyric providers.
- Keep transport controls, Production Matcher, and Provider priority unchanged.
- Debug build/full self-tests and Release build 21 packaged self-test pass;
  the arm64 ad-hoc app and DMG verify locally.
- Feature commit `d933c62` is pushed; macOS CI run `36220000743` passed. Latest
  local candidate is build 22, based on `d933c62`.
- Remaining: Product Owner GUI checks for handoff and visible lyrics, and
  restart recovery. Local `swift test` is blocked by missing XCTest in the
  active Command Line Tools installation.
- Work is isolated on `codex/player-expansion-integration`; no merge to main,
  tag, or public release has occurred.
- QA evidence: `PLAYER_EXPANSION_HANDOFF.md`.

## Current — v0.8 Final Release Candidate (build 20)

Status: FINAL RC / READY FOR RELEASE DECISION

Goal: move the existing Spotify, Apple Music, and NetEase candidate from
feature completion to production-quality behavior and a verified release
candidate.

### P0.1 — Single Installed Version

Status: DONE

- Inventory all installed and Spotlight-visible NotchMuse app bundles.
- Keep one primary build-18 candidate and recoverably archive older installed
  copies.
- Verify one launch entry, one running process, shared bundle identity, helper
  lifecycle, and retained preferences.

Exit criteria: the user cannot accidentally launch an older NotchMuse build.

Result: only `/Applications/NotchMuse.app` build `18` is the installed candidate and
Spotlight-visible. Historical build 7 and 14 records are retained in handoff; preferences remain intact and Auto Detect is selected.

### P0 — Player Ownership and Settings

Status: DONE — build 18 Auto Detect final GUI PASS

- Make Auto Detect the recommended default player mode.
- Detect Spotify (`com.spotify.client`), Apple Music (`com.apple.Music`), and
  NetEase (`com.netease.163music`).
- Keep explicit player overrides for all three players.
- Restore the missing NetEase Settings option and add regression coverage for
  the complete enum/UI/datasource/adapter path.
- On player exit, hide lyrics by default and wait for recovery; offer an option
  to keep the final lyric visible and paused.

Exit criteria: deterministic owner selection, no stale lyric after owner or
track changes, all four Settings choices persist, and regression checks pass.

### P1 — Lyrics State and Notch UX

Status: DONE — Product Owner confirms final GUI PASS

- Playing: show lyrics and scroll.
- Paused: retain lyrics and stop scrolling.
- Stopped: apply the configured hide-or-hold policy.
- Track change: clear the old lyric before loading the new lyric.
- Default to lyric-only presentation with no background.
- Support Background `None / Black / Custom`.
- Support Hide lyrics on hover `ON / OFF`, defaulting to ON.

Exit criteria: automated state checks and focused GUI regression pass across
Spotify, Apple Music, and NetEase.

Current build 18 evidence: Product Owner final GUI PASS covers Notch/current/restart
lyrics, custom-color persistence, Hide on Hover, Auto Detect combinations and
ownership/fallback/stale clearing, Sleep/Wake, and network recovery. Exact steps
and durations were not supplied.

### P2 — v0.8 Release Candidate

Status: FINAL RC / READY FOR RELEASE DECISION

- Completed build 18 real-player, lifecycle, final GUI, and 60-minute playback
  gates. Build 20 adds only the Settings redesign and passes Debug/Release
  self-tests plus bilingual real-window Settings smoke.
- Built and verified the arm64 DMG and SHA-256; documented ad-hoc signing and
  its distribution limitations.
- Synchronized status, handoff, task board, roadmap, changelog, and closure
  evidence. Ready for release review; public distribution remains separate.

Current local artifact: `0.8.0` build `20`, arm64, ad-hoc signed. Executable SHA-256
`7c52681e81f99d8f77f4778ec2926d334b4d28d0081e8bed4acdc4cc14340334`; DMG SHA-256
`0aa060361f5566bcfcb34fe4bde9c17e7d8a08dd1fcbf9fbb22226c32f8b05e3`. Runtime
evidence from build 18 remains applicable because build 20 changes only Settings
UI and localization. The candidate is FINAL RC / READY FOR RELEASE DECISION.
Ad-hoc signing, Gatekeeper
rejection, notarization, and clean-new-user distribution assessment remain
known release-review risks. This status does not authorize public release.

## Future — Website Distribution

Status: PLANNED / NOT IN DEVELOPMENT

After v0.8, plan `notchmuse.com` with a landing page, download page, and release
notes. Host only the DMG, checksum, and `latest.json`; do not upload source code
to the website.

## Completed — 10_SETTINGS_UI

Status: DONE / ARCHIVED

The approved Settings UI redesign started from stable main `101e550`, followed
`NotchMuse_Settings_UI_Redesign_PM_Handoff.md`, passed bilingual GUI and CI
verification, and was integrated into main as `279b910`. The next action is a
Product Owner release decision, not additional feature work.

## Completed Milestones

- v0.3.x: open-source beta and initial lyrics UX.
- v0.4-v0.5: evidence pipeline and bounded Provider recovery.
- v0.6.0-v0.6.1: Spotify and Apple Music production support, published.
- v0.7-v0.7.1: Matcher and metadata evidence gates completed with NO-GO for
  Production behavior changes.
- v0.8 candidate groundwork: bundled NetEase bridge, adapter, lifecycle work,
  and local build-14 artifact completed; no public v0.8 release was made.

## Product Guardrails

- Do not modify Production Matcher, thresholds, ranking, or Provider priority
  without a new independent evidence gate.
- Do not treat Provider hits as proof of visible, synchronized lyrics.
- Do not claim signing, clean-install, or public-release completion without
  direct verification.
- Do not start website implementation during the v0.8 sprint.
