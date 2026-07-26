#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${NOTCHMUSE_VERSION:-0.3.1}}"
BUILD_NUMBER="${2:-${NOTCHMUSE_BUILD_NUMBER:-4}}"
SIGN_IDENTITY="${NOTCHMUSE_SIGN_IDENTITY:--}"
APP="$ROOT/dist.noindex/NotchMuse.app"
DMG="$ROOT/dist.noindex/NotchMuse.dmg"

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$' ]] || {
  echo "Invalid version: $VERSION" >&2
  exit 1
}
[[ "$BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]] || {
  echo "Build number must be a positive integer: $BUILD_NUMBER" >&2
  exit 1
}

rm -rf "$ROOT/dist.noindex"
swift package --package-path "$ROOT/MenuBarLyrics" clean

NOTCHMUSE_VERSION="$VERSION" \
NOTCHMUSE_BUILD_NUMBER="$BUILD_NUMBER" \
NOTCHMUSE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  "$ROOT/scripts/build_dmg.sh"

[[ "$(defaults read "$APP/Contents/Info" CFBundleIdentifier)" == "app.notchmuse.mac" ]]
[[ "$(defaults read "$APP/Contents/Info" CFBundleName)" == "NotchMuse" ]]
[[ "$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)" == "$VERSION" ]]
[[ "$(defaults read "$APP/Contents/Info" CFBundleVersion)" == "$BUILD_NUMBER" ]]
file "$APP/Contents/MacOS/NotchMuse" | grep -q 'arm64'
codesign --verify --deep --strict "$APP"
hdiutil verify "$DMG" >/dev/null

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Warning: ad-hoc signed unsigned GitHub beta; macOS Gatekeeper warning is expected." >&2
else
  spctl --assess --type execute --verbose=2 "$APP"
fi

echo "Release candidate: $DMG"
