#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT="${1:-/tmp/notchmuse-7platform-report.txt}"
BIN="${TMPDIR:-/tmp}/notchmuse-benchmark-7platforms"

swift build --package-path "$ROOT/MenuBarLyrics" >/dev/null

swiftc -parse-as-library -O -swift-version 5 \
  -I "$ROOT/MenuBarLyrics/.build/debug/Modules" \
  "$ROOT/MenuBarLyrics/.build/debug/LyricsCore.build/LyricClock.swift.o" \
  "$ROOT/MenuBarLyrics/.build/debug/LyricsCore.build/LyricParser.swift.o" \
  "$ROOT/scripts/benchmark_7platforms.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Support/DebugLog.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/AppLocalization.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/SpotifyReader.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/AppleMusicAdapter.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/NetEaseEventConverger.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/NetEaseMusicAdapter.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/MusicPlayerAdapter.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/MediaRemoteBridge.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/MediaRemotePlayerAdapter.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/TrackMatcher.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsHTTP.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsCandidate.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsSelection.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsBackendShadow.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/SpotifyIdentityResolver.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LRCLIBLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/NetEaseLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LRCMuxLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/QQMusicLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/KugouLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/SodaMusicLyricsSource.swift" \
  "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsClient.swift" \
  -o "$BIN"

if [ -n "${2:-}" ]; then
  "$BIN" "$ROOT/scripts/fixtures/benchmark_100_catalog.tsv" "$ROOT/scripts/fixtures/ytm_100.tsv" "$REPORT" "$2"
else
  "$BIN" "$ROOT/scripts/fixtures/benchmark_100_catalog.tsv" "$ROOT/scripts/fixtures/ytm_100.tsv" "$REPORT"
fi
echo "Full report written to: $REPORT"
