#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist.noindex/NotchMuse.app"

if [ ! -x "$APP/Contents/MacOS/NotchMuse" ]; then
  "$ROOT/scripts/build_app.sh" >/dev/null
fi

open "$APP"
