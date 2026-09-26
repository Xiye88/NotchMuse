#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${NOTCHMUSE_VERSION:-0.8.0}}"
BUILD_NUMBER="${2:-${NOTCHMUSE_BUILD_NUMBER:-19}}"
SIGN_IDENTITY="${NOTCHMUSE_SIGN_IDENTITY:--}"
DIST="$ROOT/dist.noindex"
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

NOTCHMUSE_DIST_DIR="$DIST" \
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
[[ -d "$APP/Contents/Resources/MediaRemoteBridge/MediaRemoteAdapter.framework" ]]
[[ -x "$APP/Contents/Resources/MediaRemoteBridge/mediaremote-adapter.pl" ]]
[[ -x "$APP/Contents/Resources/MediaRemoteBridge/MediaRemoteAdapterTestClient" ]]
[[ -x "$APP/Contents/Resources/MediaRemoteBridge/mediaremote-watchdog.sh" ]]
hdiutil verify "$DMG" >/dev/null

SIGNING_KIND="Developer ID"
[[ "$SIGN_IDENTITY" == "-" ]] && SIGNING_KIND="ad-hoc"
(
  cd "$DIST"
  shasum -a 256 NotchMuse.app/Contents/MacOS/NotchMuse NotchMuse.dmg > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
  cat > BUILD-INFO.txt <<EOF_BUILD_INFO
Product: NotchMuse
Version: $VERSION
Build: $BUILD_NUMBER
Source commit: $(git -C "$ROOT" rev-parse HEAD)
Architecture: arm64
Signing: $SIGNING_KIND
Notarized: no
EOF_BUILD_INFO
)

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Warning: ad-hoc signed GitHub beta; Developer ID signing and notarization are absent." >&2
else
  spctl --assess --type execute --verbose=2 "$APP"
fi

echo "Release candidate: $DMG"
echo "Artifact metadata: $DIST/BUILD-INFO.txt and $DIST/SHA256SUMS"
