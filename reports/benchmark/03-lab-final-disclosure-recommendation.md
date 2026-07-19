# Benchmark Disclosure Recommendation

Task: 03_LAB Benchmark Disclosure

Status: Completed

Priority: P1

## Findings

- The latest reliable benchmark snapshot is VPS run `6` from 2026-07-18.
- Dataset: `extended_1000`.
- Successful matches: `636/1000`.
- Coverage: `63.6%`.
- Providers tested: LRCMux, LRCLIB, QQ Music, Soda Music, Kugou, NetEase.
- Failure analysis exists and should primarily guide Phase 2 matcher/provider optimization.

## Problems Found

- Coverage is a benchmark snapshot, not a user-facing guarantee.
- Full provider ranking and full failure tables may distract from the Beta Release.
- 2026-07-19 VPS status was not re-verified in this PM pass.

## Recommended Actions

- Publicly disclose the benchmark at summary level:
  - `1000-track mixed-language benchmark`
  - `6 providers tested`
  - `63.6% latest verified snapshot`
- Do not publish full track list, VPS details, or provider-by-provider ranking in README.
- Keep detailed failure analysis in maintainer reports for Phase 2.

## Need PM Decision

- Confirm whether README should keep the exact `63.6%` number.
