# NotchMuse for Windows · M1 development

Native .NET 8 / WPF bootstrap, WinRT SMTC session listener and a conservative multi-source lyrics pipeline. M2 desktop modes and M3 studio UI are not implemented in this milestone.

Requirements: Windows 10 build 19041 or later (Windows 11 recommended), .NET 8 SDK to build. No API keys or account setup.

```powershell
cd NotchMuseWindows
dotnet restore
dotnet build -c Release --no-restore
dotnet test -c Release --no-build
dotnet run --project src/NotchMuse.App -c Release --no-build
```

Run the original pinned Mac fixtures directly from the Git object database; fetch the reference branch first if absent:

```powershell
git fetch origin codex/preview-startup-updates
dotnet run --project tools/NotchMuse.Benchmark -c Release -- --repo .. --output artifacts/benchmark
```

Optional benchmark flags: `--platform apple|spotify|netease|qq|kugou|soda|youtube`, `--limit 1..100`, `--catalog path`, `--youtube path`. Partial samples return failure; a passing complete profile needs at least 95 vocal matches and no instrumental matches. Reports are JSON per track plus Markdown totals. Preserve complete diagnostics when comparing network runs. Matching a candidate is engine acceptance, not human verification of every vocal timestamp.

All 36 catalog profiles depend on the player exposing an SMTC session. Browser auto-detection intentionally requires a recognized music site suffix. A browser session with no site identity can be selected through the all-apps mode; call applications remain blocked. This can reduce automatic discovery for browser implementations that omit site identity, rather than incorrectly treating arbitrary video as music.

`docs/ARCHITECTURE.md` records boundaries and technology decisions; `docs/PROJECT_HANDOFF.md` records the current checkpoint. Read the milestone report for measured limitations. Do not infer release readiness from a successful build.
