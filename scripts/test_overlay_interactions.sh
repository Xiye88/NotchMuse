#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
swift build --package-path "$ROOT/MenuBarLyrics"
"$ROOT/MenuBarLyrics/.build/debug/NotchMuse" --free-lyrics-self-test
"$ROOT/MenuBarLyrics/.build/debug/NotchMuse" --settings-interaction-self-test
