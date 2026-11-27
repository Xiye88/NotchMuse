#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == --help ]]; then
  exec "$ROOT/scripts/run_7platform_benchmark.sh" --help
fi
exec "$ROOT/scripts/run_7platform_benchmark.sh" \
  --catalog "$ROOT/scripts/fixtures/benchmark_800_catalog.tsv" \
  --ytm "$ROOT/scripts/fixtures/ytm_800.tsv" \
  --concurrency 4 "$@"
