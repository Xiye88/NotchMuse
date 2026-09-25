#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MenuBarLyrics"
DIST="$ROOT/dist.noindex"
APP="$DIST/NotchMuse.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ENTITLEMENTS="$PROJECT/Resources/NotchMuse.entitlements"
BRIDGE_SOURCE="$PROJECT/Vendor/MediaRemoteBridge"
BRIDGE_DEST="$RESOURCES/MediaRemoteBridge"
VERSION="${NOTCHMUSE_VERSION:-0.8.0}"
BUILD_NUMBER="${NOTCHMUSE_BUILD_NUMBER:-19}"
BUNDLE_ID="app.notchmuse.mac"
SIGN_IDENTITY="${NOTCHMUSE_SIGN_IDENTITY:--}"
DEFAULT_FEEDBACK_EMAIL="ztongxue3@gmail.com"
FEEDBACK_EMAIL="${FEEDBACK_EMAIL:-$DEFAULT_FEEDBACK_EMAIL}"

verify_hash() {
  local path="$1"
  local expected="$2"
  [[ "$(/usr/bin/shasum -a 256 "$path" | /usr/bin/awk '{print $1}')" == "$expected" ]] || {
    echo "Unexpected MediaRemote bridge hash: $path" >&2
    exit 1
  }
}

if [[ "$FEEDBACK_EMAIL" != "FEEDBACK_EMAIL" && ! "$FEEDBACK_EMAIL" =~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ]]; then
  echo "Invalid FEEDBACK_EMAIL" >&2
  exit 1
fi

verify_hash "$BRIDGE_SOURCE/MediaRemoteAdapter.framework/MediaRemoteAdapter" "e5241c9d92cc5e79fb4d67d9ff029e0781e49b23cbea84018378e5ea888b50b5"
verify_hash "$BRIDGE_SOURCE/MediaRemoteAdapterTestClient" "a9953e9db2cd3022f3392ee618a8bb76ede264358d34e5e3dc8844a1be1049bd"
verify_hash "$BRIDGE_SOURCE/mediaremote-adapter.pl" "fd6ce4dfd6cbe1578e0effeaf8c38468299a596d055975a1a978c9a6df8e9760"
perl -c "$BRIDGE_SOURCE/mediaremote-adapter.pl" >/dev/null
lipo "$BRIDGE_SOURCE/MediaRemoteAdapter.framework/MediaRemoteAdapter" -verify_arch arm64 x86_64
lipo "$BRIDGE_SOURCE/MediaRemoteAdapterTestClient" -verify_arch arm64 x86_64
[[ -f "$BRIDGE_SOURCE/LICENSE" && -f "$BRIDGE_SOURCE/VERSION.json" ]]

mkdir -p "$DIST"

cd "$PROJECT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$PROJECT/.build/release/NotchMuse" "$MACOS/NotchMuse"
cp "$PROJECT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp -R "$PROJECT/Resources/en.lproj" "$PROJECT/Resources/zh-Hans.lproj" "$RESOURCES/"
cp -R "$BRIDGE_SOURCE" "$BRIDGE_DEST"
cp "$PROJECT/Resources/mediaremote-watchdog.sh" "$BRIDGE_DEST/mediaremote-watchdog.sh"
chmod 755 "$BRIDGE_DEST/mediaremote-adapter.pl" "$BRIDGE_DEST/MediaRemoteAdapterTestClient" "$BRIDGE_DEST/mediaremote-watchdog.sh"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RESOURCES/THIRD_PARTY_NOTICES.md"
mkdir -p "$RESOURCES/LICENSES"
cp "$ROOT/LICENSES/Apache-2.0.txt" "$RESOURCES/LICENSES/Apache-2.0.txt"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>NotchMuse</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>NotchMuse</string>
  <key>CFBundleDisplayName</key>
  <string>NotchMuse</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>FeedbackEmail</key>
  <string>$FEEDBACK_EMAIL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSExceptionDomains</key>
    <dict>
      <key>mobilecdn.kugou.com</key>
      <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key>
        <true/>
      </dict>
    </dict>
  </dict>
  <key>NSAppleEventsUsageDescription</key>
  <string>NotchMuse reads the current track from the selected music player to show synced lyrics.</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Info.plist" >/dev/null
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$BRIDGE_DEST/MediaRemoteAdapter.framework" >/dev/null
  codesign --force --sign - "$BRIDGE_DEST/MediaRemoteAdapterTestClient" >/dev/null
  codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP" >/dev/null
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BRIDGE_DEST/MediaRemoteAdapter.framework" >/dev/null
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BRIDGE_DEST/MediaRemoteAdapterTestClient" >/dev/null
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP" >/dev/null
fi
codesign --verify --deep --strict "$APP"
"$MACOS/NotchMuse" --self-test
test -x "$BRIDGE_DEST/mediaremote-adapter.pl"
test -x "$BRIDGE_DEST/MediaRemoteAdapterTestClient"
test -x "$BRIDGE_DEST/mediaremote-watchdog.sh"
perl -c "$BRIDGE_DEST/mediaremote-adapter.pl" >/dev/null
/bin/sh -n "$BRIDGE_DEST/mediaremote-watchdog.sh"
/usr/bin/perl \
  "$BRIDGE_DEST/mediaremote-adapter.pl" \
  "$BRIDGE_DEST/MediaRemoteAdapter.framework" \
  "$BRIDGE_DEST/MediaRemoteAdapterTestClient" \
  test
echo "$APP"
