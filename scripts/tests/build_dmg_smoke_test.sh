#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
DMG_PATH="$ROOT_DIR/dist/Glint.dmg"

rm -f "$DMG_PATH"

zsh "$ROOT_DIR/scripts/build_dmg.sh"

test -f "$DMG_PATH"
hdiutil imageinfo "$DMG_PATH" >/dev/null

CODESIGN_DETAILS=$(codesign -dv --verbose=4 "$ROOT_DIR/dist/Glint.app" 2>&1)

echo "$CODESIGN_DETAILS" | grep -F "Identifier=local.glint" >/dev/null
echo "$CODESIGN_DETAILS" | grep -F "Info.plist entries=" >/dev/null
echo "$CODESIGN_DETAILS" | grep -F "Sealed Resources version=" >/dev/null

printf 'DMG smoke test passed for %s\n' "$DMG_PATH"
