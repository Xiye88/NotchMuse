#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/MenuBarLyrics/Vendor/MediaRemoteBridge"
REPOSITORY="https://github.com/MxIris-LyricsX-Project/mediaremote-adapter-framework.git"
COMMIT="6bbb7d30f9ddb209a583fa509b9ca145df97f502"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

git clone --quiet "$REPOSITORY" "$WORK_DIR/source"
git -C "$WORK_DIR/source" checkout --quiet "$COMMIT"
cmake -S "$WORK_DIR/source" -B "$WORK_DIR/build"
cmake --build "$WORK_DIR/build" --config Release

rm -rf "$VENDOR_DIR/MediaRemoteAdapter.framework"
cp -R "$WORK_DIR/build/MediaRemoteAdapter.framework" "$VENDOR_DIR/"
cp "$WORK_DIR/build/MediaRemoteAdapterTestClient" "$VENDOR_DIR/"
cp "$WORK_DIR/source/bin/mediaremote-adapter.pl" "$VENDOR_DIR/"
cp "$WORK_DIR/source/LICENSE" "$VENDOR_DIR/LICENSE"
chmod 755 "$VENDOR_DIR/MediaRemoteAdapterTestClient" "$VENDOR_DIR/mediaremote-adapter.pl"

echo "Rebuilt MediaRemote bridge at $COMMIT"
echo "Update VERSION.json only after reviewing the new artifact hashes."
