#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist.noindex"
APP="$DIST/NotchMuse.app"
DMG="$DIST/NotchMuse.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/notchmuse-dmg.XXXXXX")"
SIGN_IDENTITY="${NOTCHMUSE_SIGN_IDENTITY:--}"

trap 'rm -rf "$STAGING"' EXIT

"$ROOT/scripts/build_app.sh"
ditto "$APP" "$STAGING/NotchMuse.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "NotchMuse" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG" >/dev/null
fi

hdiutil verify "$DMG" >/dev/null
echo "$DMG"
