#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Optional frozen inputs: prepare_appcast.sh APP DMG NOTES OUTPUT_XML
[[ $# -le 4 ]] || { echo "Usage: $0 [APP [DMG [NOTES [OUTPUT_XML]]]]" >&2; exit 1; }
APP="${1:-$ROOT/dist.noindex/NotchMuse.app}"
DMG="${2:-$ROOT/dist.noindex/NotchMuse.dmg}"
SPARKLE="$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
NOTES="${3:-$ROOT/docs/releases/v$VERSION/RELEASE_NOTES.en.md}"
OUTPUT="${4:-$ROOT/dist.noindex/appcast-staging/$VERSION-$BUILD/appcast.xml}"
STAGING="$(dirname "$OUTPUT")"
DOWNLOAD_PREFIX="https://github.com/Xiye88/NotchMuse/releases/download/v$VERSION/"
NOTES_PREFIX="https://notchmuse.com/releases/v$VERSION/"

[[ -f "$DMG" && -f "$NOTES" && -x "$SPARKLE" ]]
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]
mkdir -p "$STAGING"
cp "$DMG" "$STAGING/NotchMuse.dmg"
cp "$NOTES" "$STAGING/NotchMuse.md"
"$SPARKLE" --account notchmuse --maximum-deltas 0 \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --release-notes-url-prefix "$NOTES_PREFIX" \
  --link "https://notchmuse.com/" \
  -o "$OUTPUT" "$STAGING"

"$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/bin/sign_update" --account notchmuse "$OUTPUT"
"$ROOT/MenuBarLyrics/.build/artifacts/sparkle/Sparkle/bin/sign_update" --account notchmuse --verify "$OUTPUT"
grep -q 'sparkle:edSignature=' "$OUTPUT"
grep -Fq "<sparkle:version>$BUILD</sparkle:version>" "$OUTPUT"
grep -Fq "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$OUTPUT"
grep -Fq "${DOWNLOAD_PREFIX}NotchMuse.dmg" "$OUTPUT"
grep -Fq "${NOTES_PREFIX}NotchMuse.md" "$OUTPUT"
echo "Staged only: $OUTPUT"
