#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.8.0}"
BUILD_NUMBER="${2:?Usage: $0 [version] build-number}"
BUILT_APP="$ROOT/dist.noindex/NotchMuse.app"
INSTALLED_APP="/Applications/NotchMuse.app"
BACKUP_DIR="$ROOT/dist.noindex/local-backups"

[[ "$BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]] || {
  echo "Build number must be a positive integer: $BUILD_NUMBER" >&2
  exit 1
}

NOTCHMUSE_VERSION="$VERSION" NOTCHMUSE_BUILD_NUMBER="$BUILD_NUMBER" \
  "$ROOT/scripts/build_app.sh"

[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_APP/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT_APP/Contents/Info.plist")" == "$BUILD_NUMBER" ]]
codesign --verify --deep --strict "$BUILT_APP"

deploy_tmp_dir="$(mktemp -d /tmp/notchmuse-deploy.XXXXXX)"
staged_app="$deploy_tmp_dir/NotchMuse.app"
ditto "$BUILT_APP" "$staged_app"
codesign --verify --deep --strict "$staged_app"

osascript -e 'tell application id "app.notchmuse.mac" to quit' >/dev/null 2>&1 || true
for deploy_attempt in 1 2 3 4 5; do
  pgrep -f '^/Applications/NotchMuse.app/Contents/MacOS/NotchMuse$' >/dev/null || break
  sleep 1
done
if pgrep -f '^/Applications/NotchMuse.app/Contents/MacOS/NotchMuse$' >/dev/null; then
  echo "Installed NotchMuse did not quit" >&2
  exit 1
fi

backup_app=""
if [[ -d "$INSTALLED_APP" ]]; then
  mkdir -p "$BACKUP_DIR"
  old_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_APP/Contents/Info.plist")"
  old_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INSTALLED_APP/Contents/Info.plist")"
  backup_app="$BACKUP_DIR/NotchMuse-$old_version-build$old_build-$(date +%Y%m%d-%H%M%S).app"
  mv "$INSTALLED_APP" "$backup_app"
fi

if ! mv "$staged_app" "$INSTALLED_APP"; then
  [[ -n "$backup_app" ]] && mv "$backup_app" "$INSTALLED_APP"
  exit 1
fi
rmdir "$deploy_tmp_dir"

codesign --verify --deep --strict "$INSTALLED_APP"
open "$INSTALLED_APP"
for deploy_attempt in 1 2 3 4 5; do
  pgrep -f '^/Applications/NotchMuse.app/Contents/MacOS/NotchMuse$' >/dev/null && break
  sleep 1
done
pgrep -f '^/Applications/NotchMuse.app/Contents/MacOS/NotchMuse$' >/dev/null

echo "version=$VERSION"
echo "build=$BUILD_NUMBER"
echo "commit=$(git -C "$ROOT" rev-parse HEAD)"
echo "installed=$INSTALLED_APP"
[[ -n "$backup_app" ]] && echo "backup=$backup_app"
