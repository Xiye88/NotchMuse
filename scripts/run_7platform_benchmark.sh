#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT="${1:-/tmp/notchmuse-7platform-report.txt}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/notchmuse-benchmark.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
BIN="$BUILD_DIR/notchmuse-benchmark-7platforms"
if [[ "${1:-}" == --* ]]; then
  args=("$@")
else
  args=("$ROOT/scripts/fixtures/benchmark_100_catalog.tsv" "$ROOT/scripts/fixtures/ytm_100.tsv" "$REPORT")
  if [ -n "${2:-}" ]; then args+=("$2"); fi
fi

# Swap the transport at compile time. The app sources and deadlines stay in use.
SOURCE="$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsHTTP.swift"
TRANSPORT='let result = try await URLSession.shared.data(for: request, delegate: timing)'
test "$(rg -Fc "$TRANSPORT" "$SOURCE")" = 1
sed "s/$TRANSPORT/let result = try await BenchmarkLyricsHTTP.shared.data(for: request, deadline: deadline)/" \
  "$SOURCE" > "$BUILD_DIR/LyricsHTTP.swift"

# Keep a single anonymous Soda device per run so identical searches share a key.
CLIENT="$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsClient.swift"
sed 's/SodaMusicLyricsSource()/SodaMusicLyricsSource(deviceID: "7382026773187073251", installID: "7392026773187073251")/g' \
  "$CLIENT" > "$BUILD_DIR/LyricsClient.swift"

swift build --disable-sandbox --package-path "$ROOT/MenuBarLyrics" >/dev/null

swiftc -parse-as-library -O -swift-version 5 \
  -I "$ROOT/MenuBarLyrics/.build/debug/Modules" \
  "$ROOT/MenuBarLyrics/.build/debug/LyricsCore.build/LyricClock.swift.o" \
  "$ROOT/MenuBarLyrics/.build/debug/LyricsCore.build/LyricParser.swift.o" \
  "$ROOT/scripts/benchmark_7platforms.swift" \
  "$ROOT/scripts/benchmark_lyrics_http.swift" \
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
  "$BUILD_DIR/LyricsHTTP.swift" \
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
  "$BUILD_DIR/LyricsClient.swift" \
  -o "$BIN"

"$BIN" "${args[@]}"
