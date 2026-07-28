# NotchMuse Developer Documentation

This area contains implementation and quality-engineering information. Product usage, demos, installation, and support remain in the main [README](../README.md).

Benchmark coverage, provider health, candidate scores, and Evidence Gate results are engineering diagnostics. They are not user-experience ratings and do not predict lyrics availability for an individual song.

## Architecture

NotchMuse is a native Swift macOS menu bar app.

- `AppDelegate` owns startup, single-instance behavior, Settings, and lifecycle coordination.
- `SpotifyReader` reads current Spotify playback through macOS automation.
- `LyricsClient` queries lyrics providers and returns synchronized lyrics.
- `MenuBarController` renders Status Bar lyrics.
- `OverlayLyricsWindow` renders Notch Mode lyrics.
- `SettingsWindowController` manages user preferences.
- `lyrics-provider-benchmark/` is an independent lab and does not run inside the app.

## Build and Test

```sh
./scripts/build_app.sh
./scripts/build_dmg.sh
./scripts/build_release.sh 0.3.1 4
swift run --package-path MenuBarLyrics NotchMuse --self-test
./scripts/run_live_matrix.sh
```

Build output:

```text
dist.noindex/NotchMuse.app
dist.noindex/NotchMuse.dmg
```

The default GitHub beta build is unsigned/ad-hoc signed. Manual release steps are tracked in [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md).

## Lyrics Quality Benchmark

The independent [Lyrics Provider Benchmark](../lyrics-provider-benchmark/README.md) measures coverage, provider contribution, latency, and failure reasons against a repeatable dataset. Benchmark results are engineering evidence, not a promise that every track will have lyrics.

## Evidence Gate

Production matching behavior changes only when evidence shows that the change improves useful matches without introducing confirmed false positives.

The minimum gate is:

1. Collect representative failed tracks.
2. Classify Provider, Network, Parser, and Matcher failures separately.
3. Capture rejected candidates, scores, reject reasons, and final decisions in DEBUG-only evidence.
4. Compare the proposed rule against the same benchmark dataset.
5. Keep production behavior unchanged when evidence is incomplete or ambiguous.

## Matcher Design

The matcher evaluates normalized track metadata against provider candidates, scores plausible matches, rejects candidates below the acceptance threshold, and treats close top candidates as ambiguous. DEBUG-only decision logging records candidate scores and rejection reasons without changing Release behavior.

Normalization and fallback rules are deliberately conservative: accepting the wrong lyrics is treated as worse than returning no lyrics.

## Provider Analysis

Provider health is evaluated independently from Matcher quality:

- **LRCMux** is the primary coverage source; no-result responses must remain distinct from network and parser failures.
- **LRCLIB** is a supplemental source; transient retry experiments apply only to retryable network failures.
- **NetEase** remains an unhealthy benchmark source until its endpoint/parser path is validated.
- **QQ Music, Soda Music, and Kugou** provide secondary evidence and fallback coverage.

Provider priority changes require repeated benchmark evidence. A single run or isolated outage is not sufficient.
