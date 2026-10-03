# Task Completion Report

Task: 03_LAB Lyrics Quality Snapshot

Status: Completed

Priority: P1

## Findings

- Latest VPS 1000-song benchmark report is available.
- Source: VPS `/opt/lyrics-provider-benchmark`, SQLite run `6`, dataset `extended_1000`.
- Run time: started `2026-07-18T00:00:08+00:00`, finished `2026-07-18T00:34:49+00:00`.
- Sample size: `1000` tracks.
- Current coverage: `63.6%`.
- Successful songs: `636`.
- Failed songs: `364`.
- Providers tested: `6`.
- Provider names: `LRCMux`, `LRCLIB`, `QQ`, `Soda`, `Kugou`, `NetEase`.

Benchmark capabilities currently available:

- Daily automated 1000-song VPS benchmark.
- Provider coverage and success-rate tracking.
- Unique provider contribution analysis.
- Category and language coverage summaries.
- Failed lyrics database with failure reason labels.
- Provider language matrix.
- Retry impact simulation.
- Matching optimization simulation v2.
- Matching optimization spec for future NotchMuse migration.
- Markdown reports plus historical run records and coverage CSV trend data.

## Problems Found

- Main current failure source is `network_error`: `248` failed tracks.
- Matching quality still has visible room to improve:
  - `artist_mismatch`: `77`
  - `version_mismatch`: `27`
  - `title_mismatch`: `8`
- `provider_error`: `4`.
- Coverage is uneven by language/category; CJK coverage remains weaker than English/independent samples.
- Benchmark estimates optimization impact, but does not prove NotchMuse app-side behavior until migrated and tested in the main app.

## Recommended Actions

- For README/GitHub, present benchmark as a dedicated Lyrics Quality Lab, separate from the NotchMuse app.
- Use `63.6% coverage on a 1000-track mixed-language benchmark` as the current public snapshot.
- Mention all six tested providers: LRCMux, LRCLIB, QQ, Soda, Kugou, NetEase.
- Emphasize that the benchmark now guides matching improvements, not just provider selection.
- Next app-side priority, when PM approves, should be retry strategy first, then artist normalization, then title/version normalization.

## Need PM Decision

- Decide whether the README should show the exact current coverage number `63.6%` or phrase it as an internal benchmark snapshot.
- Decide whether to disclose provider-level performance publicly or keep it internal.
- Decide whether NotchMuse Beta should claim multi-language lyrics coverage, or keep the wording conservative until CJK coverage improves.
- Decide when to migrate the benchmark-generated matching spec into NotchMuse LyricsClient.
