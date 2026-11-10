#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FRAMEWORK="$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
TEST_BUILD=$(mktemp -d /tmp/notchmuse-updates.XXXXXX)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -parse-as-library -F "$FRAMEWORK" -Xlinker -rpath -Xlinker "$FRAMEWORK" "$ROOT/MenuBarLyrics/Sources/MenuBarLyrics/App/UpdateFeedback.swift" "$ROOT/MenuBarLyrics/Tests/UpdateFeedbackTests.swift" -o "$TEST_BUILD/tests"
"$TEST_BUILD/tests"
