#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${NOTCHMUSE_DIST_DIR:-$ROOT/dist.noindex}"
APP="$DIST/NotchMuse.app"
DMG="$DIST/NotchMuse.dmg"
BACKGROUND="$DIST/NotchMuse-DMG-Background.png"
SIGN_IDENTITY="${NOTCHMUSE_SIGN_IDENTITY:--}"

NOTCHMUSE_DIST_DIR="$DIST" "$ROOT/scripts/build_app.sh"
swift "$ROOT/scripts/render_dmg_background.swift" \
  "$ROOT/scripts/assets/notchmuse-dmg-wave-source.png" \
  "$BACKGROUND"

rm -f "$DMG"
uvx --from dmgbuild==1.6.7 \
  --with ds_store==1.3.3 \
  --with mac_alias==2.2.3 \
  dmgbuild \
  -s "$ROOT/scripts/notchmuse_dmg.py" \
  -D "application=$APP" \
  -D "background=$BACKGROUND" \
  -D "guide=$ROOT/scripts/assets/安装说明.txt" \
  "NotchMuse" "$DMG"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG" >/dev/null
fi

hdiutil verify "$DMG" >/dev/null
echo "$DMG"
