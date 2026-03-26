#!/usr/bin/env zsh
set -euo pipefail

LABEL="com.hy-mt.omlx"
UID_LABEL="gui/$(id -u)/${LABEL}"

launchctl bootout "${UID_LABEL}" >/dev/null 2>&1 || true
echo "Stopped launch agent: ${UID_LABEL}"
