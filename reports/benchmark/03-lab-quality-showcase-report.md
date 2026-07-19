# Task Completion Report

Task: 03_LAB Quality Showcase Report

Status: Completed

Priority: P1

## Findings

- Benchmark Dataset: `lyrics-provider-benchmark/datasets/extended_1000.tsv`.
- Dataset size: `1000` tracks plus header.
- Dataset categories include `english_pop`, `chinese_pop`, `japanese`, `korean`, `independent`, and `spotify_hot`.
- Latest verified VPS 1000-song benchmark snapshot: run `6`, dataset `extended_1000`.
- Latest verified run time: `2026-07-18T00:00:08+00:00` to `2026-07-18T00:34:49+00:00`.
- Overall Coverage: `63.6%`.
- Successful songs: `636 / 1000`.
- Failed songs: `364 / 1000`.
- Providers tested: `6`.
- Provider names: `LRCMux`, `LRCLIB`, `QQ`, `Soda`, `Kugou`, `NetEase`.
- Provider Coverage summary for GitHub: six-provider benchmark with `63.6%` overall coverage on a mixed-language 1000-track test set.
- Failure Analysis from latest verified run:
  - `network_error`: `248`
  - `artist_mismatch`: `77`
  - `version_mismatch`: `27`
  - `title_mismatch`: `8`
  - `provider_error`: `4`
- VPS benchmark service was previously verified as daily automated with `lyrics-benchmark.timer`.
- Available benchmark outputs include Markdown reports, historical run reports, coverage history CSV, failed-track analysis, provider language matrix, retry analysis, optimization simulation, and matching optimization spec.

Suggested GitHub README / Release copy:

> NotchMuse includes a separate Lyrics Quality Lab used to benchmark lyrics provider coverage across a 1000-track mixed-language dataset. The current verified VPS run reached 63.6% overall coverage across six providers: LRCMux, LRCLIB, QQ, Soda, Kugou, and NetEase. The lab tracks provider success, failed-song patterns, network instability, language/category coverage, and matching issues so future app-side improvements can be driven by measured data instead of guesswork.

Short showcase bullets:

- Independent Lyrics Quality Lab, separate from the macOS app.
- 1000-track mixed-language benchmark dataset.
- Six lyrics providers tested.
- Current verified coverage: `63.6%`.
- Failure analysis separates provider/network errors from matching issues.
- Daily VPS benchmark pipeline with historical reports.

## Problems Found

- Current session could not re-authenticate to the VPS on `2026-07-19`; SSH password login was rejected twice.
- Because of that, today’s latest VPS run status cannot be verified from this session.
- Latest reliable VPS benchmark data remains the previously verified run `6` from `2026-07-18`.
- Provider-by-provider latest coverage numbers are not available in local synced reports.
- Public copy should avoid implying that benchmark coverage equals guaranteed user-facing lyrics availability.
- CJK coverage is known to be weaker than English/independent samples, based on prior lab findings.
- Third-party provider availability is network-dependent and may fluctuate between runs.

## Recommended Actions

- Use the `63.6% / 1000 tracks / six providers` number as a clearly labeled verified benchmark snapshot.
- Present the lab as an engineering quality system, not a guarantee of complete lyrics coverage.
- Keep the public provider list simple: LRCMux, LRCLIB, QQ, Soda, Kugou, NetEase.
- For README, include the short showcase bullets rather than full failure tables.
- For release notes, mention that the benchmark is separate from the app and does not modify NotchMuse runtime behavior.
- Before publishing exact provider-by-provider rankings, export the latest VPS `reports/latest.md` or SQLite summary again.

## Need PM Decision

- Decide whether GitHub README should show exact coverage `63.6%` or a softer phrase like “measured on an internal 1000-track benchmark.”
- Decide whether to disclose failure breakdown publicly, or keep it for maintainer documentation.
- Decide whether provider names should be listed in README or only in technical docs.
- Decide whether to wait for a fresh `2026-07-19` VPS verification before final GitHub release copy.
- Decide how strongly to message CJK support while coverage remains uneven.
