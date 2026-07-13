#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MenuBarLyrics"
BINARY="${TMPDIR:-/tmp}/menubarlyrics-live-matrix"
RESULTS="${TMPDIR:-/tmp}/menubarlyrics-live-matrix.tsv"

swiftc -parse-as-library -O -o "$BINARY" \
  "$ROOT/scripts/live_matrix.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LyricParser.swift" \
  "$PROJECT/Sources/MenuBarLyrics/SpotifyReader.swift" \
  "$PROJECT/Sources/MenuBarLyrics/TrackMatcher.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LRCLIBLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/NetEaseLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LRCMuxLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/QQMusicLyricsSource.swift"

: > "$RESULTS"
for index in {0..19}; do
  "$BINARY" "$index" | tee -a "$RESULTS"
done

hits="$(awk -F '\t' '$3 != "MISS" { count++ } END { print count + 0 }' "$RESULTS")"
if [[ "$hits" -lt 19 ]]; then
  echo "Live matrix failed: $hits/20 songs matched" >&2
  exit 1
fi
echo "Live matrix passed: $hits/20 songs matched"
