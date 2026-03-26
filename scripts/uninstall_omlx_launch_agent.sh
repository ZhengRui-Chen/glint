#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LABEL="com.hy-mt.omlx"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_LABEL="gui/$(id -u)/${LABEL}"

launchctl bootout "${UID_LABEL}" >/dev/null 2>&1 || true
rm -f "${PLIST_DST}"
echo "Uninstalled launch agent: ${PLIST_DST}"
