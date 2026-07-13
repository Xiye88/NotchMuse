#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MenuBarLyrics"
BINARY="${TMPDIR:-/tmp}/menubarlyrics-live-matrix"
RESULTS="/tmp/menubarlyrics-live-matrix.tsv"
FIXTURE="$ROOT/scripts/fixtures/live_tracks.tsv"

swiftc -parse-as-library -O -o "$BINARY" \
  "$ROOT/scripts/live_matrix.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LyricParser.swift" \
  "$PROJECT/Sources/MenuBarLyrics/SpotifyReader.swift" \
  "$PROJECT/Sources/MenuBarLyrics/TrackMatcher.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LyricsHTTP.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LRCLIBLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/NetEaseLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/LRCMuxLyricsSource.swift" \
  "$PROJECT/Sources/MenuBarLyrics/QQMusicLyricsSource.swift"

"$BINARY" "$FIXTURE" "$RESULTS"
