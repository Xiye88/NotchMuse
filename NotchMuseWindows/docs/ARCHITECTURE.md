# Windows technical selection

C# 12 / .NET 8 / WPF, net8.0-windows10.0.19041.0, x64 initially. WPF is the only UI framework; no browser, account, developer client ID or secret is required. Use software rendering to avoid hardware rendering requests. This does not by itself prove no discrete GPU activation on every driver.

Core contains immutable metadata/timing records, Unicode/Chinese normalization, metadata cleaning, LRC/Enhanced LRC/YRC/KRC parsing, conservative identity scoring and independent timeline corroboration. Sources owns a shared HttpClient, bounded requests, parallel direct sources, resolver fallback, bounded memory cache and observable failures. Platform owns WinRT SMTC events and Win32 hooks; it does not poll idle sessions. App owns cancellation when tracks change and dispatches immutable snapshots onto WPF.

```text
NotchMuseWindows/
  src/NotchMuse.Core/          identity, parsers, selection, player catalog
  src/NotchMuse.Sources/       LRCLIB, NetEase, QQ, Kugou, LRCMux, engine
  src/NotchMuse.Platform/      SMTC discovery and playback control
  src/NotchMuse.App/           WPF M1 diagnostic host
  tests/NotchMuse.Tests/       offline and HTTP fixture regressions
  tools/NotchMuse.Benchmark/   original TSV runner, per-track JSON reports
  docs/                       Windows handoff, parity notes, evidence
  packaging/                  reserved for M4
  NotchMuseWindows.sln
```

UI milestones M2–M3 retain the supplied dark/warm tokens, 224px sidebar, four navigation items, native vectors and timer lifecycle requirements. M1 host is a diagnostic surface, not final visual acceptance. Desktop overlays, idle animations, installers and updater are later milestones.

CI is path-isolated and runs restore, Release build and tests. The benchmark reads original fixture bytes using git show at the pinned reference, with explicit --catalog/--youtube overrides. It records network errors independently from no lyrics and never treats HTTP success alone as a match. Platform labels in a catalog simulation are metadata profiles, not proof of 36 real-player compatibility. Physical SMTC, DPI and power measurements remain separate.
