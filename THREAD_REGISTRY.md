# NotchMuse Thread Registry

Last Updated: 2026-07-18

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
