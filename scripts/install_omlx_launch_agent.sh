#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LABEL="com.hy-mt.omlx"
PLIST_TEMPLATE="${ROOT_DIR}/launchd/com.hy-mt.omlx.plist.template"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_LABEL="gui/$(id -u)/${LABEL}"

mkdir -p "${HOME}/Library/LaunchAgents" "${ROOT_DIR}/.runtime/omlx/logs"

sed \
  -e "s|__ROOT__|${ROOT_DIR}|g" \
  "${PLIST_TEMPLATE}" > "${PLIST_DST}"

launchctl bootout "${UID_LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_DST}"
launchctl kickstart -k "${UID_LABEL}"

echo "Installed launch agent: ${PLIST_DST}"
