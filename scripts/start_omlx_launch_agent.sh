#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LABEL="com.hy-mt.omlx"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_DOMAIN="gui/$(id -u)"
UID_LABEL="${UID_DOMAIN}/${LABEL}"

if [[ ! -f "${PLIST_DST}" ]]; then
  echo "LaunchAgent plist not found: ${PLIST_DST}"
  echo "Run scripts/install_omlx_launch_agent.sh first."
  exit 1
fi

if launchctl print "${UID_LABEL}" >/dev/null 2>&1; then
  launchctl kickstart -k "${UID_LABEL}"
else
  launchctl bootstrap "${UID_DOMAIN}" "${PLIST_DST}"
fi

echo "Started launch agent: ${UID_LABEL}"
