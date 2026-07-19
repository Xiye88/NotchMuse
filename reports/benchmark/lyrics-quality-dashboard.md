# Task Completion Report

Task: Lyrics Quality Dashboard

Status: Complete

Priority: P1

## Findings

- Current Coverage: 98/100 songs matched, 98.00% coverage. Source: existing local live matrix artifact `/tmp/menubarlyrics-live-matrix.tsv`, modified 2026-07-18 16:02:05 +0800. No latest local/VPS `reports/latest.md`, `reports/latest.json`, or benchmark SQLite run artifact was found under the workspace.
- Live matrix provider contribution: QQ 59, Kugou 22, NetEase 8, LRCLIB 5, LRCMux 3, Soda 1. Non-hit rows: ERROR 2, MISS 0.
- Live matrix latency snapshot: median 446 ms, p95 1715 ms, max 8849 ms.
- Provider count: 6.
- Provider names: LRCLIB, NetEase, LRCMux, QQ, Kugou, Soda.
- Benchmark dataset capacity: `lyrics-provider-benchmark/datasets/extended_1000.tsv` has 1000 tracks plus header. `default.tsv` has 100 tracks plus header. `scripts/fixtures/live_tracks.tsv` has 100 tracks plus header.
- Benchmark storage/reporting capacity: SQLite schema exists for songs, providers, benchmark runs, provider results, missing lyrics, and failed tracks. CLI supports init, run, and report commands.
- Benchmark reporting capacity: `latest.md`, `latest.json`, history reports, provider ranking, unique provider contribution, duplicate coverage via per-song provider results, failure reasons, failed song details, 7-day average coverage, latency, provider strategy, language matrix, matching simulation, retry analysis, recommendation, and coverage history are implemented in the benchmark package.
- Failure reason labels supported by the benchmark: `no_lyrics_found`, `matching_failed`, `api_unavailable`, `invalid_response`, `version_mismatch`, `timeout`, `unknown_error`.
- Lightweight benchmark health check: `python3 -m unittest discover -s tests` passed 14 tests in 0.045s from `lyrics-provider-benchmark`.
- Matching protection exists in benchmark logic: acceptance threshold is 80, duration difference over 12 seconds scores 0, title similarity below 0.82 scores 0, weak artist similarity scores 0, and ambiguous top candidates within 6 points are rejected.

## Problems Found

- No current VPS benchmark output was present locally, so the dashboard cannot claim latest VPS 1000-dataset coverage.
- No local benchmark SQLite database was present under the workspace, so provider ranking and failure reasons from a full 1000-run cannot be reported as measured release data.
- Current coverage is based on an existing 100-track live matrix artifact, not the 1000-track benchmark dataset.
- The live matrix artifact records final winning source per track and ERROR/MISS rows, but not the full per-provider failure reason breakdown available from the Python benchmark runner.
- Third-party provider behavior is network-dependent and can change without an app release.

## Recommended Actions

- Use the 98.00% local live matrix coverage only as Beta snapshot evidence, with the source and 100-track scope stated wherever it is shown.
- Before public release notes claim 1000-dataset quality, run the benchmark CLI on `extended_1000.tsv` and publish the generated `latest.md`/`latest.json` from SQLite.
- Keep the 6-provider list and benchmark capability bullets in the release dashboard; they are supported by source code and tests.
- Treat ERROR rows in live matrix as likely third-party/network instability until a SQLite benchmark run records provider-level failure reasons.
- Preserve the current matching protection language in release materials so Beta users understand why some near matches are intentionally rejected.

## Need PM Decision

- Decide whether Beta release messaging may use the existing 98/100 local live matrix snapshot, clearly labeled as local 100-track evidence.
- Decide whether a full VPS 1000-dataset benchmark is required before publishing the Beta release page.
- Decide how prominently to disclose known limitations: third-party service availability, strict mismatch protection, network fluctuation, and missing VPS benchmark artifact.
- Decide whether provider ranking should be shown from the 100-track live matrix winner counts now, or held until a full SQLite benchmark report exists.
