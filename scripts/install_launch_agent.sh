#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PLIST_TEMPLATE="${ROOT_DIR}/launchd/com.hy-mt.omlx-restart.plist.template"
PLIST_DST="${HOME}/Library/LaunchAgents/com.hy-mt.omlx-restart.plist"
RUNTIME_DIR="${ROOT_DIR}/.runtime/omlx"
PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"

mkdir -p "${HOME}/Library/LaunchAgents" "${RUNTIME_DIR}/logs"
sed \
  -e "s|__ROOT__|${ROOT_DIR}|g" \
  -e "s|__PYTHON__|${PYTHON_BIN}|g" \
  "${PLIST_TEMPLATE}" > "${PLIST_DST}"
launchctl unload "${PLIST_DST}" >/dev/null 2>&1 || true
launchctl load "${PLIST_DST}"
echo "Installed launch agent: ${PLIST_DST}"
