# NotchMuse Thread Registry

## Active - v0.8.0 Productization (2026-10-02)

| Workspace | Status | Scope |
| --- | --- | --- |
| 00_PM | ACTIVE | Integrate isolated Build 40 Preview, verify gates, and request final publication decision. |
| 01_APP | DONE | Settings polish and Preview interaction changes returned to this branch. |
| 06_DOCS | DONE | Native lyrics feasibility and accurate current README returned to this branch. |

Preview GUI and staged update verification remain pending; the public Beta 3 and archived Menu Bar Space thread are unchanged.

## Archived Experiment - Menu Bar Space (2026-10-02)

| Thread | Status | Source | Boundary |
| --- | --- | --- | --- |
| Menu Bar Space experiment | ARCHIVED | `origin/codex/menu-bar-space` @ `62b47067a601fb48a6292efdfcee10e8c92d4036`; `MENU_BAR_SPACE_HANDOFF.md` on that branch | EXPERIMENTAL / PAUSED; local branch/worktree retained; not merged or released |

This is an archived experiment, not an additional numbered workspace or a current product feature.

## Beta 3 Release Approval - 2026-09-27

- Product Owner accepted Candidate Build 38 and authorized GitHub sync/publication.
- Target: v0.8.0-beta.3, Build 38; implementation commit `1b2d191`.
- Added four anchored lyric positions, 12 solid and 10 gradient presets, labeled custom colors; fixed Notch solid-color rendering and background opacity controls.
- Debug/Release builds, full self-tests and Settings interaction checks passed; user GUI acceptance PASS.
- GitHub main source SHA `149e75f001e8fbe70a489a0e0fc0d797877c0c5e`; CI run `36328894758` PASS. Beta 3 prerelease: https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.0-beta.3
- Public DMG: https://github.com/Xiye88/NotchMuse/releases/download/v0.8.0-beta.3/NotchMuse.dmg; SHA-256 `5f8e8c2a487d31bae69bc230a22bf17c3fe0f8c05a515732ce20e51117397cee`. Public download matches locally verified DMG.
- Website: https://notchmuse.com and https://www.notchmuse.com each verified with three Beta 3 download links. The former Beta 2 index is backed up on the origin. Earlier candidate/Beta 2 sections below are historical.
- Ad-hoc signing remains; no notarization. Stable local installation remains untouched.


## Historical Public Beta 2 — 2026-09-26

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


Last Updated: 2026-09-26

## v0.8 Final Engineering Workspaces

| Workspace | Status | Priority | Dependency | Responsibility |
| --- | --- | --- | --- | --- |
| `09_REPO_ARCHITECTURE` | ARCHIVED | COMPLETED | Candidate Freeze `3fb6946` | Repository structure, tests, CI, documentation, and artifact standardization. Final head `d5673b9b5b9e25baff4abb57db2264f30ace19c2`; integrated into main as `7bc74ac`. |
| `10_SETTINGS_UI` | DONE | VISUAL POLISH v2 ACCEPTED | Main `a5f1938` | Product Owner accepted preview images; CI passed. Unified packaging with the separate player candidate is pending. |

`10_SETTINGS_UI` started after `09_REPO_ARCHITECTURE` completed. Its second
round is visual-only; keep player and lyrics logic unchanged.

## Current Registry

| Workspace | Status | Responsibility |
| --- | --- | --- |
| `00_PM` | ACTIVE | Single PM/integration entry point |
| `01_APP` | ARCHIVED | P0 implementation merged into the candidate |
| `02_RELEASE` | ACTIVE | Build-21 installed artifact verified; public release awaits Product Owner decision |
| `03_LAB` | ARCHIVED | Reopen only for a new evidence question |
| `04_UX` | ARCHIVED | Settings redesign and final GUI smoke complete |
| `05_MATCHER` | ARCHIVED | Production Matcher remains frozen |
| `06_DOCS` | ARCHIVED | Sprint documents synchronized; reopen at release gate |
| `07_QA` | ARCHIVED | Installed build-21 Settings GUI manual PASS; NetEase short smoke passed |

This table supersedes the historical thread statuses below. Reuse these
numbers; do not create duplicate role workspaces. Archived workspaces keep
their Git history.

## Long-Term Thread Map

Thread ID: `019f741e-4308-7360-82f8-4e5c0d1c9224`

Current Name: `Project manager`

New Name: `00_PM | NotchMuse Project Manager`

Role: Single project management entry point. Owns project status, task routing, thread registry, blockers, and phase decisions.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f56f6-ed0a-77e0-80fe-5a9b3542046c`

Current Name: `总版本`

New Name: `01_APP | NotchMuse App Core Development`

Role: App core development thread for Swift code, AppKit UI, Settings, lyrics display, provider integration, packaging, and local install validation.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f7455-8378-7393-9a36-3f31367adea1`

Current Name: `执行 Release QA 阻塞检查`

New Name: `02_RELEASE | NotchMuse Release Engineering`

Role: Release engineering thread for Developer ID signing, codesign, notarization, stapling, Gatekeeper, DMG, and clean install release checks.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f68a3-f53c-7d42-b04f-8f1bc290378e`

Current Name: `Lyrics-provider-benchmark`

New Name: `03_LAB | Lyrics Quality Benchmark Lab`

Role: Lyrics benchmark lab for VPS, provider tests, coverage, SQLite reports, daily 1000-song benchmark, failed songs, and provider analysis.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f7455-863a-7b02-8d82-9faa0be1c4a9`

Current Name: `Final UX Verification Thread`

New Name: `04_UX | NotchMuse UX Verification`

Role: UX verification thread for first-user journey, DMG install, launch, permissions, Spotify, lyrics display, Settings, and display-mode QA.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f7439-65d9-7a60-9a3b-7d39aa947909`

Current Name: `Lyrics Matching Architecture Review`

New Name: `05_MATCHER | Lyrics Matching Architecture`

Role: Matcher architecture thread for Benchmark-to-App matching roadmap, Swift/Python matcher parity, normalization rules, retry strategy, and false-positive risk control.

Status: Active

Action: Rename / Keep

---

Thread ID: `019f7455-84e6-7c11-823e-d9436f4fa410`

Current Name: `准备 GitHub 发布材料`

New Name: `06_DOCS | GitHub Release Documentation`

Role: GitHub release documentation thread for README, screenshots, demo GIF plan, Release Notes, CHANGELOG, LICENSE, and third-party notices.

Status: Active

Action: Rename / Keep

## Archived / One-Time Threads

Thread ID: `019f7439-62bf-78a3-a5dd-3fdd6ede3c55`

Current Name: `NotchMuse Release Candidate QA`

New Name: unchanged

Role: One-time Phase 1 release candidate audit.

Status: Archived

Action: Archive

---

Thread ID: `019f7439-6457-73c2-81d3-67cba06ccade`

Current Name: `GitHub Release Preparation`

New Name: unchanged

Role: One-time GitHub release checklist audit, superseded by `06_DOCS`.

Status: Archived

Action: Archive

---

Thread ID: `019f7455-8ae9-75c2-9fb8-1ee8bea17cf0`

Current Name: `生成歌词质量基准快照`

New Name: unchanged

Role: One-time Beta lyrics quality snapshot, superseded by `03_LAB`.

Status: Archived

Action: Archive

## Notes

- No new long-term thread was created during this audit.
- Existing high-context threads were reused wherever possible.
- Future execution threads should only be created for bounded 2-3 hour tasks and archived after their Task Completion Report is saved.

## Thread Creation Policy

1. Long-term threads should be reused first.
2. Any new thread creation must be confirmed by `00_PM | NotchMuse Project Manager`.
3. Before creating a new thread, `00_PM` must decide:
   - Whether an existing thread already covers the role.
   - Whether the work is only a one-time task.
   - Whether the thread is worth long-term maintenance.
4. One-time tasks must not become long-term threads. Use temporary task mode, save the Task Completion Report, then archive the thread.
5. Any new long-term thread must:
   - Receive a stable number.
   - Define its role.
   - Be written into `THREAD_REGISTRY.md`.
   - Update `PROJECT_STATUS.md`.

## Beta Release Thread Usage

Current Beta Release work continues through existing threads only:

- `02_RELEASE | NotchMuse Release Engineering`
- `06_DOCS | GitHub Release Documentation`
- `04_UX | NotchMuse UX Verification`
- `03_LAB | Lyrics Quality Benchmark Lab`

Do not create new Release-related threads during the current Beta Release phase.

## Communication Policy

Project Manager communication to the Product Owner must use Chinese by default.

Rules:
- Explanations, summaries, status updates, blocker reports, and next-step recommendations should be written in Chinese.
- Technical terms may stay in English when that is clearer, such as `Developer ID signing`, `notarization`, `Gatekeeper`, `DMG`, `README`, and `Release Notes`.
- GitHub-facing user documents should remain in English, including `README.md`, `CHANGELOG.md`, and Release Notes.
- Project management files may use English or mixed Chinese/English when that is easier to maintain.
- Every PM report to the Product Owner must include:
  - 当前阶段
  - 已完成
  - 当前阻塞
  - 下一步动作
  - 需要决策事项
