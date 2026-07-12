#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MenuBarLyrics"
DIST="$ROOT/dist"
APP="$DIST/MenuBarLyrics.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

cd "$PROJECT"
swift build -c release
swift run MenuBarLyrics --self-test

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$PROJECT/.build/release/MenuBarLyrics" "$MACOS/MenuBarLyrics"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MenuBarLyrics</string>
  <key>CFBundleIdentifier</key>
  <string>local.menubarlyrics.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MenuBarLyrics</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>MenuBarLyrics reads the current Spotify track to show synced lyrics in the menu bar.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
