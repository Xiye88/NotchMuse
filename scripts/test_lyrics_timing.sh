#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_BUILD=$(mktemp -d /tmp/notchmuse-timing.XXXXXX)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -emit-library -emit-module -module-name LyricsCore "$ROOT"/MenuBarLyrics/Sources/LyricsCore/*.swift -o "$TEST_BUILD/libLyricsCore.dylib" -emit-module-path "$TEST_BUILD/LyricsCore.swiftmodule"
swiftc -parse-as-library -I "$TEST_BUILD" -L "$TEST_BUILD" -lLyricsCore -Xlinker -rpath -Xlinker "$TEST_BUILD" "$ROOT/MenuBarLyrics/Tests/LyricTimingTests.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/UI/LyricHighlightLayout.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/"*LyricsSource.swift "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsHTTP.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/TrackMatcher.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsClient.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsBackendShadow.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/SpotifyIdentityResolver.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Players/SpotifyReader.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsCandidate.swift" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/Lyrics/LyricsSelection.swift" -o "$TEST_BUILD/tests"
"$TEST_BUILD/tests" "$ROOT/docs/reports/lyrics/phase2-provider-audit/netease-studio-redacted.yrc"
