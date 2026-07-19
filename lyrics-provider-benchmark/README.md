# Lyrics Provider Benchmark

Independent coverage tester for NotchMuse lyric providers. It does not import or modify the NotchMuse macOS app.

## Run Locally

```sh
cd lyrics-provider-benchmark
python3 -m unittest discover -s tests
python3 -m benchmark.cli --db data/benchmark.sqlite3 init
python3 -m benchmark.cli --db data/benchmark.sqlite3 run --dataset datasets/extended_1000.tsv --dataset-name extended_1000 --sample-size 1000
```

Reports are written to:

```text
reports/latest.md
reports/latest.json
```

## What It Measures

- total song coverage
- per-provider success and failure counts
- first successful provider ranking
- unique provider contribution
- duplicate coverage
- failure reasons
- failed songs database
- 7 day average trend
- latency

Failure reasons use these stable labels:

```text
no_lyrics_found
matching_failed
api_unavailable
invalid_response
version_mismatch
timeout
unknown_error
```

## VPS Layout

```text
/opt/lyrics-provider-benchmark
/var/lib/lyrics-provider-benchmark/benchmark.sqlite3
/var/log/lyrics-provider-benchmark/
```

Install the files under `deploy/` into `/etc/systemd/system/`, then enable the timer:

```sh
systemctl daemon-reload
systemctl enable --now lyrics-benchmark.timer
```

The timer runs daily and samples from `datasets/extended_1000.tsv` with the current date as the random seed.

Skipped: PostgreSQL and dashboard. Add them when historical data or human browsing needs outgrow SQLite reports.
