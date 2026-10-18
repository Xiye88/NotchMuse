#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_BUILD=$(mktemp -d /tmp/notchmuse-selection.XXXXXX)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -emit-library -emit-module -module-name LyricsCore "$ROOT"/MenuBarLyrics/Sources/LyricsCore/*.swift -o "$TEST_BUILD/libLyricsCore.dylib" -emit-module-path "$TEST_BUILD/LyricsCore.swiftmodule"
for SUITE in LyricsSelectionTests LyricsProviderCandidateTests LyricsRecallRecoveryTests; do
 swiftc -parse-as-library -I "$TEST_BUILD" -L "$TEST_BUILD" -lLyricsCore -Xlinker -rpath -Xlinker "$TEST_BUILD" "$ROOT/MenuBarLyrics/Tests/$SUITE.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/SpotifyReader.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/"*LyricsSource.swift "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsHTTP.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/TrackMatcher.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsCandidate.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsSelection.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsClient.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsBackendShadow.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/SpotifyIdentityResolver.swift" -o "$TEST_BUILD/$SUITE"
 "$TEST_BUILD/$SUITE"
done
