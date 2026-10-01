#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist.noindex/NotchMuse.app"
DMG="$ROOT/dist.noindex/NotchMuse.dmg"
SPARKLE="$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
STAGING="$ROOT/dist.noindex/appcast-staging/$VERSION-$BUILD"

[[ -f "$DMG" && -x "$SPARKLE" ]]
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]
mkdir -p "$STAGING"
cp "$DMG" "$STAGING/NotchMuse.dmg"
cp "$ROOT/RELEASE_NOTES_v$VERSION.md" "$STAGING/NotchMuse.md"
"$SPARKLE" --account notchmuse --maximum-deltas 0 \
  --download-url-prefix "https://github.com/Xiye88/NotchMuse/releases/download/v$VERSION/" \
  --link "https://notchmuse.com/" \
  -o "$STAGING/appcast.xml" "$STAGING"

grep -q 'sparkle:edSignature=' "$STAGING/appcast.xml"
grep -q 'NotchMuse.dmg' "$STAGING/appcast.xml"
echo "Staged only: $STAGING/appcast.xml"
