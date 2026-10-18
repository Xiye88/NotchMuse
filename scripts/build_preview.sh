#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist.noindex/preview"
HELPER="$ROOT/scripts/preview_lifecycle.py"
mkdir -p "$DIST"
LOCK="/tmp/notchmuse-preview-delivery-${UID}.lock"
mkdir "$LOCK" 2>/dev/null || { echo "Preview delivery already in progress: $LOCK" >&2; exit 1; }
trap 'rmdir "$LOCK"' EXIT
BUILD_NUMBER="$(/usr/bin/python3 "$HELPER" next-build "${1:-}")"
STABLE_BEFORE="$(/usr/bin/python3 "$HELPER" stable-hash)"

NOTCHMUSE_PREVIEW=1 \
NOTCHMUSE_DIST_DIR="$DIST" \
NOTCHMUSE_VERSION=0.8.0 \
NOTCHMUSE_BUILD_NUMBER="$BUILD_NUMBER" \
NOTCHMUSE_SKIP_BRIDGE_RUNTIME_TEST=1 \
  "$ROOT/scripts/build_app.sh"

APP="$DIST/NotchMuse Preview.app"
if [[ "${NOTCHMUSE_INSTALL_PREVIEW:-1}" == "1" ]]; then
  /usr/bin/python3 "$HELPER" deliver "$APP" "$DIST" "$BUILD_NUMBER" "$STABLE_BEFORE"
else
  /usr/bin/python3 "$HELPER" verify "$APP" "$BUILD_NUMBER"
  /usr/bin/python3 "$HELPER" verify-stable "$STABLE_BEFORE"
  echo "Preview Build: $BUILD_NUMBER (candidate only)"
  echo "Installed: NO"
  echo "Running: not changed"
  echo "Rollback Build: not changed"
  echo "Stable unchanged: YES (no install performed)"
fi
