#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist.noindex/preview"
BUILD_NUMBER="${1:-41}"

NOTCHMUSE_PREVIEW=1 \
NOTCHMUSE_DIST_DIR="$DIST" \
NOTCHMUSE_VERSION=0.8.0 \
NOTCHMUSE_BUILD_NUMBER="$BUILD_NUMBER" \
NOTCHMUSE_SKIP_BRIDGE_RUNTIME_TEST=1 \
  "$ROOT/scripts/build_app.sh"

APP="$DIST/NotchMuse Preview.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "app.notchmuse.mac.preview" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" == "$BUILD_NUMBER" ]]
codesign --verify --deep --strict "$APP"

if [[ "${NOTCHMUSE_INSTALL_PREVIEW:-0}" == "1" ]]; then
  rm -rf "/Applications/NotchMuse Preview.app"
  /usr/bin/ditto "$APP" "/Applications/NotchMuse Preview.app"
fi

echo "$APP"
