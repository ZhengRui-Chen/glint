#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="${ROOT_DIR}/configs/omlx.env"
SESSION_NAME="${1:-hy-omlx}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8001}"
API_KEY="${OMLX_API_KEY:-local-hy-key}"
PATTERN="omlx serve --model-dir ${ROOT_DIR}/models"

echo "Process check:"
ps -Ao pid,etime,%cpu,%mem,command | rg "${PATTERN}" || echo "not running"
echo
echo "tmux check:"
tmux ls 2>/dev/null | rg "^${SESSION_NAME}:" || echo "tmux session not running"
echo
echo "API check:"
python3 - <<PY
import urllib.request
import urllib.error

req = urllib.request.Request(
    "http://${HOST}:${PORT}/v1/models",
    headers={"Authorization": "Bearer ${API_KEY}"},
)
try:
    with urllib.request.urlopen(req, timeout=5) as response:
        print(response.status)
        print(response.read().decode())
except urllib.error.HTTPError as exc:
    print(f"HTTP {exc.code}")
    print(exc.read().decode())
except Exception as exc:
    print(type(exc).__name__, exc)
PY
