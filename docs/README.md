# NotchMuse Developer Documentation

This area contains implementation and quality-engineering information. Product usage, demos, installation, and support remain in the main [README](../README.md).

Benchmark coverage, provider health, candidate scores, and Evidence Gate results are engineering diagnostics. They are not user-experience ratings and do not predict lyrics availability for an individual song.

## Architecture

NotchMuse is a native Swift macOS menu bar app.

- `Sources/MenuBarLyrics/App/` contains app lifecycle ownership; `main.swift` remains at the target root as the executable entry point.
- `Sources/MenuBarLyrics/Players/` contains Spotify, Apple Music, NetEase, shared player-selection, and bundled MediaRemote bridge integration.
- `Sources/MenuBarLyrics/Lyrics/` contains lyric providers, networking, caching, and matching.
- `Sources/MenuBarLyrics/UI/` contains menu-bar, Notch, settings, and display components.
- `Sources/MenuBarLyrics/Support/` contains shared accessibility and logging helpers. `AppLocalization.swift` remains at the target root because its source fallback locates `Resources` relative to `#filePath`.
- `Sources/LyricsCore/` is the pure logic library target for lyric parsing and clocking; `Tests/MenuBarLyricsTests/` tests that module through SwiftPM.
- The production executable remains the `MenuBarLyrics` target, with the same product name, bundle identity, and runtime target identity.
- The v0.8.0 candidate supports Spotify, Apple Music, and NetEase Cloud Music. Auto Detect is the default, with manual player selection retained. NetEase uses the bundled MediaRemote bridge and macOS private APIs.
- `lyrics-provider-benchmark/` is an independent lab and does not run inside the app.

## Build and Test

```sh
cd MenuBarLyrics
swift build -c debug
swift test
cd ..
./scripts/build_app.sh
./scripts/build_dmg.sh
./scripts/build_release.sh 0.8.0 19
swift run --package-path MenuBarLyrics NotchMuse --self-test
./scripts/run_live_matrix.sh
```

The v0.8.0 candidate is not publicly released. GitHub Actions CI runs on
`macos-15` with Swift 6 and verifies Debug/self-test, `swift test`, Release
packaging, DMG integrity, and repository checks. `build_release.sh` recreates
`dist.noindex`; do not use it when that directory contains artifacts you need
to keep.

Build output:

```text
dist.noindex/NotchMuse.app
dist.noindex/NotchMuse.dmg
```

Install a local Release Candidate for manual QA with one command:

```sh
./scripts/deploy_local_candidate.sh 0.8.0 19
```

The command builds the app, verifies its version and signature, backs up the
current `/Applications/NotchMuse.app` under `dist.noindex/local-backups/`,
installs and launches the new build, then reports its version, build, and Git
commit.

The v0.8.0 candidate is ad-hoc signed and has not been publicly released.
Manual release steps are tracked in [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md).

`build_release.sh` writes `BUILD-INFO.txt` and `SHA256SUMS` beside the app and
DMG. The build-info file records the source commit, version/build, architecture,
signing type, and notarization state; the checksum file covers the executable
and DMG.

## Lyrics Quality Benchmark

The independent [Lyrics Provider Benchmark](../lyrics-provider-benchmark/README.md) measures coverage, provider contribution, latency, and failure reasons against a repeatable dataset. Benchmark results are engineering evidence, not a promise that every track will have lyrics.

## Evidence Gate

Production matching behavior changes only when evidence shows that the change improves useful matches without introducing confirmed false positives.

Production Matcher behavior, thresholds, and Provider priority remain frozen
through the v0.8.0 architecture cleanup. The historical v0.5/v0.7 evidence
below records earlier matcher gates; it does not describe current player
support.

Phase 4 uses a Benchmark-only offline simulator to compare duration, exact
artist, album/version, and bounded title signals. The Top Songs dataset is a
chart-derived user-value proxy, not Spotify telemetry or a product-level
availability claim.

Natural run `19` produced complete second identity for `489` ambiguity rows;
`464` strict metadata-equivalent rows are eligible for offline simulation,
not production acceptance.

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

The v0.8.0 runtime supports NetEase playback through the bundled bridge. The
benchmark notes below describe historical benchmark health and do not override
the verified runtime support status.

Provider health is evaluated independently from Matcher quality:

- **LRCMux** is the primary coverage source; no-result responses must remain distinct from network and parser failures.
- **LRCLIB** is a supplemental source; transient retry experiments apply only to retryable network failures.
- **NetEase** remains an unhealthy benchmark source until its endpoint/parser path is validated.
- **QQ Music, Soda Music, and Kugou** provide secondary evidence and fallback coverage.

Provider priority changes require repeated benchmark evidence. A single run or isolated outage is not sufficient.

v0.5 does not add Providers and does not optimize for maximum aggregate
coverage.

## Engineering Evidence

The dated execution reports, their archive, and the current architecture
cleanup report are indexed in [reports/README.md](../reports/README.md).

## Queued Product Work

The approved Settings redesign handoff is stored at
[NotchMuse_Settings_UI_Redesign_PM_Handoff.md](project/NotchMuse_Settings_UI_Redesign_PM_Handoff.md).
It is registered as `10_SETTINGS_UI` and remains queued until `00_PM` opens it
from the latest stable Architecture SHA.
