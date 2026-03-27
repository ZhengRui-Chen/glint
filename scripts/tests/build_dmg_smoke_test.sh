#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
DMG_PATH="$ROOT_DIR/dist/Glint.dmg"

rm -f "$DMG_PATH"

zsh "$ROOT_DIR/scripts/build_dmg.sh"

test -f "$DMG_PATH"
hdiutil imageinfo "$DMG_PATH" >/dev/null

printf 'DMG smoke test passed for %s\n' "$DMG_PATH"
