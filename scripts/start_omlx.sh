#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="${ROOT_DIR}/configs/omlx.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

MODEL_DIR="${ROOT_DIR}/${OMLX_MODEL_DIR:-models}"
HOST="${OMLX_HOST:-127.0.0.1}"
PORT="${OMLX_PORT:-8001}"
API_KEY="${OMLX_API_KEY:-local-hy-key}"
BASE_PATH="${OMLX_BASE_PATH:-${HOME}/.omlx}"

exec "${ROOT_DIR}/.venv-omlx/bin/omlx" serve \
  --model-dir "${MODEL_DIR}" \
  --host "${HOST}" \
  --port "${PORT}" \
  --api-key "${API_KEY}" \
  --base-path "${BASE_PATH}" \
  --no-cache
