# Benchmark Disclosure Recommendation

Task: 03_LAB Benchmark Disclosure Recommendation

Status: Completed

Priority: P1

## Findings

- 当前可用于 GitHub Open Source Beta Release 的最新可靠数据来源，是 Lyrics Quality Lab 已验证的 VPS benchmark run `6`。
- 数据源：`lyrics-provider-benchmark/datasets/extended_1000.tsv`。
- 样本规模：`1000` tracks。
- Dataset 类型：mixed-language benchmark，覆盖 `english_pop`、`chinese_pop`、`japanese`、`korean`、`independent`、`spotify_hot`。
- 最新已验证运行时间：`2026-07-18T00:00:08+00:00` 到 `2026-07-18T00:34:49+00:00`。
- Overall Coverage：`63.6%`。
- 成功歌曲：`636 / 1000`。
- 失败歌曲：`364 / 1000`。
- Provider 数量：`6`。
- Provider 名称：`LRCMux`、`LRCLIB`、`QQ`、`Soda`、`Kugou`、`NetEase`。
- Failure Analysis 可用，但更适合放在 maintainer / engineering docs，不建议作为 README 主展示内容。
- 主要 Failure breakdown：
  - `network_error`: `248`
  - `artist_mismatch`: `77`
  - `version_mismatch`: `27`
  - `title_mismatch`: `8`
  - `provider_error`: `4`

建议披露等级：

| 项目 | 是否公开 | 建议位置 | 说明 |
| --- | --- | --- | --- |
| Benchmark Dataset | 公开概要 | README / Release Notes | 公开 `1000-track mixed-language benchmark`，不必逐条公开 track list。 |
| Coverage | 谨慎公开 | README 简短说明 | 可写 `63.6% on the latest verified 1000-track benchmark snapshot`。 |
| Provider 统计 | 部分公开 | README / Technical Notes | 公开 Provider names 和 provider count；暂不公开 provider-by-provider ranking。 |
| Failure Analysis | 不放 README 主体 | Maintainer docs / issue roadmap | 可总结为 network instability and matching mismatches，不建议公开完整 failure table。 |
| VPS 运行状态 | 内部说明 | Release checklist | 公开说 “benchmarked by an independent lab pipeline” 即可，不需要公开 VPS 细节。 |

## Problems Found

- `63.6%` 是 benchmark snapshot，不等于真实用户播放场景下的 guaranteed lyrics coverage。
- `network_error` 占失败大头，公开完整 breakdown 容易让读者误解为 App 本身不稳定。
- Provider-by-provider 最新覆盖率没有同步到本地 release report；不建议在 GitHub README 写精确 provider ranking。
- CJK coverage 仍然不如 English / independent samples，公开多语言能力时需要克制。
- 2026-07-19 当前会话未能重新验证 VPS 登录状态；最终 release 前如要写 “latest daily benchmark”，需要重新导出最新 VPS report。

## Recommended Actions

- README 建议公开：
  - `Lyrics Quality Lab`
  - `1000-track mixed-language benchmark`
  - `6 lyrics providers tested`
  - `latest verified snapshot: 63.6% coverage`
  - `failure analysis and matching simulation are used internally to guide future improvements`
- README 不建议公开：
  - 完整 Dataset track list
  - Provider-by-provider ranking
  - 完整 Failure Analysis table
  - VPS IP、systemd timer、SQLite path 等部署细节
- GitHub Release Notes 建议使用更稳妥表述：

> Lyrics quality is tracked through a separate Benchmark Lab using a 1000-track mixed-language dataset across six providers. The latest verified snapshot reached 63.6% coverage. The benchmark also records failure reasons such as provider/network errors and matching mismatches, giving maintainers a clear path for future lyrics quality improvements.

- 如果 PM 希望 README 更保守，可以改成：

> Lyrics quality is measured with an internal 1000-track benchmark across six providers. Current results are used to guide provider fallback, matching, and retry improvements.

- Final Beta Release 前，建议重新导出一次 VPS `reports/latest.md`，确认是否仍使用 `63.6%`。

## Need PM Decision

- 是否在 public README 直接写出 `63.6% Coverage`？
- 是否公开 Provider names：`LRCMux`、`LRCLIB`、`QQ`、`Soda`、`Kugou`、`NetEase`？
- 是否公开 Dataset 只是 `1000-track mixed-language benchmark`，还是公开具体 track list？
- 是否把 Failure Analysis 放进 public docs，还是仅保留在 maintainer / internal release notes？
- 如果 2026-07-19 VPS 最新状态无法验证，是否允许用 `latest verified snapshot from 2026-07-18` 作为 Beta Release 数据？
