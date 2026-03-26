#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/mac-app/HYMTQuickTranslate/Glint.xcodeproj"
SCHEME="Glint"
DERIVED_DATA_PATH="$ROOT_DIR/.runtime/xcode-derived-data/Glint"
SOURCE_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Glint.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP_PATH="$DIST_DIR/Glint.app"

xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH"

mkdir -p "$DIST_DIR"
ditto "$SOURCE_APP_PATH" "$DIST_APP_PATH"

printf 'Built app at %s\n' "$DIST_APP_PATH"
