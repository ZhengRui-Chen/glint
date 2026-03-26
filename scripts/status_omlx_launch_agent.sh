#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LABEL="com.hy-mt.omlx"
UID_LABEL="gui/$(id -u)/${LABEL}"
LOG_DIR="${ROOT_DIR}/.runtime/omlx/logs"

echo "launchctl status:"
launchctl print "${UID_LABEL}" 2>/dev/null || echo "not loaded"
echo
echo "process check:"
ps -Ao pid,etime,%cpu,%mem,command | rg "omlx serve --model-dir ${ROOT_DIR}/models" || echo "not running"
echo
echo "log check:"
tail -n 40 "${LOG_DIR}/omlx-launchd.log" 2>/dev/null || echo "no stdout log"
echo
tail -n 40 "${LOG_DIR}/omlx-launchd.err.log" 2>/dev/null || echo "no stderr log"
