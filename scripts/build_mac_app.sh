#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/mac-app/Glint.xcodeproj"
SCHEME="Glint"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="$ROOT_DIR/.runtime/xcode-derived-data/Glint"
SOURCE_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Glint.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP_PATH="$DIST_DIR/Glint.app"

xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP_PATH"
ditto "$SOURCE_APP_PATH" "$DIST_APP_PATH"

printf 'Built %s app at %s\n' "$CONFIGURATION" "$DIST_APP_PATH"
