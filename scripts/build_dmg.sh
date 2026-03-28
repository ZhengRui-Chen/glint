#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Glint.app"
DMG_PATH="$DIST_DIR/Glint.dmg"
VOLUME_NAME="Glint"
RUNTIME_DIR="$ROOT_DIR/.runtime"
mkdir -p "$RUNTIME_DIR"
STAGING_ROOT=$(mktemp -d "$RUNTIME_DIR/dmg-staging.XXXXXX")
STAGING_DIR="$STAGING_ROOT/$VOLUME_NAME"

cleanup() {
  rm -rf "$STAGING_ROOT"
}

trap cleanup EXIT

CONFIGURATION=Release zsh "$ROOT_DIR/scripts/build_mac_app.sh"

mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/Glint.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

printf 'Built DMG at %s\n' "$DMG_PATH"
