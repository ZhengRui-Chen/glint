#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SESSION_NAME="${1:-hy-omlx}"

zsh "${ROOT_DIR}/scripts/stop_omlx.sh" || true
tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
sleep 2
zsh "${ROOT_DIR}/scripts/start_omlx_tmux.sh" "${SESSION_NAME}"
echo "Restarted oMLX in tmux session: ${SESSION_NAME}"
