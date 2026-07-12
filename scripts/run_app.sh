#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/MenuBarLyrics.app"

if [ ! -x "$APP/Contents/MacOS/MenuBarLyrics" ]; then
  "$ROOT/scripts/build_app.sh" >/dev/null
fi

open "$APP"
