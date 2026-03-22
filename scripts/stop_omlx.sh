#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PATTERN="omlx serve --model-dir ${ROOT_DIR}/models"

if pgrep -f "${PATTERN}" >/dev/null 2>&1; then
  pkill -f "${PATTERN}"
  echo "Stopped oMLX processes matching: ${PATTERN}"
else
  echo "No running oMLX process found for: ${PATTERN}"
fi
