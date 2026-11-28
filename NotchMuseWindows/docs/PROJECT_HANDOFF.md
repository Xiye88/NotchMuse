# Windows M1 handoff · 2026-11-25

- Version: 0.9.0 development; milestone M1 IN PROGRESS, no release.
- Branch: feat/windows-mvp; base origin/main 8262456ad79f80a48fbb405d899538ec6cc17120.
- Read-only Mac reference: 895bc4cc479a802f4785620fc2c10faeae152c81 (Preview95).
- Scope: engine, SMTC, player policy, benchmark CLI, WPF bootstrap, isolated CI.
- Build/test/online benchmark/physical QA: pending; no acceptance claims yet.
- Environment: downloaded official .NET SDK 8.0.428, verified its published SHA-512; local temporary installation, no system configuration changes.
- Source isolation: user explicitly requires every change under NotchMuseWindows and windows-ci.yml. Accordingly this Windows handoff takes precedence over the root AGENTS request to update shared docs/project files; shared macOS PM documents remain read-only.
- Known reference differences: QQMusicLyricsSource.swift is the actual QQ file; fixtures exist in the reference branch, not main. Windows enforces the requested strict Tier-4 fallback rather than Mac's weaker empty-album five-line exception. Mac matcher uses eight-second preliminary studio ranking, selection uses five seconds; Windows applies five seconds to both.
- Performance limits require measurement; managed WPF runtime working set below 30 MB is a risk, not a guarantee. No forced working-set trimming will be used to disguise allocation.
- Next: compile the native event-driven listener and engine, regression tests, run original catalog/YouTube fixtures, report actual results and unresolved provider/network failures.
