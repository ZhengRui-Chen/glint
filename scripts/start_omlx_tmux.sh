#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SESSION_NAME="${1:-hy-omlx}"

if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
  echo "tmux session already exists: ${SESSION_NAME}"
  exit 0
fi

tmux new-session -d -s "${SESSION_NAME}" \
  "cd ${ROOT_DIR} && ./scripts/start_omlx.sh"

echo "Started tmux session: ${SESSION_NAME}"
