#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
zsh "${ROOT_DIR}/scripts/stop_omlx_launch_agent.sh"
zsh "${ROOT_DIR}/scripts/start_omlx_launch_agent.sh"
echo "Restarted launch agent: com.hy-mt.omlx"
