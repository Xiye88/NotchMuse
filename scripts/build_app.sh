#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MenuBarLyrics"
DIST="$ROOT/dist"
APP="$DIST/NotchMuse.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$PROJECT"
swift build -c release
"$PROJECT/.build/release/NotchMuse" --self-test

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$PROJECT/.build/release/NotchMuse" "$MACOS/NotchMuse"
cp "$PROJECT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RESOURCES/THIRD_PARTY_NOTICES.md"
mkdir -p "$RESOURCES/LICENSES"
cp "$ROOT/LICENSES/Apache-2.0.txt" "$RESOURCES/LICENSES/Apache-2.0.txt"

cat > "$CONTENTS/Info.plist" <<'PLIST'
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
  <string>app.notchmuse.mac</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>NotchMuse</string>
  <key>CFBundleDisplayName</key>
  <string>NotchMuse</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.3.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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
  <string>NotchMuse reads the current Spotify track to show synced lyrics in the menu bar.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
