from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from hy_mt_deploy.service_config import OMLXConfig, load_env_file


def main() -> int:
    env = load_env_file(ROOT / "configs" / "omlx.env")
    config = OMLXConfig.from_env(root=ROOT, env=env)

    payload = {
        "model": "HY-MT1.5-1.8B-4bit",
        "messages": [
            {
                "role": "user",
                "content": (
                    "将以下文本翻译为中文，注意只需要输出翻译后的结果，不要额外解释：\n\n"
                    "It is a pleasure to meet you."
                ),
            }
        ],
        "max_tokens": 64,
        "temperature": 0.2,
    }
    request = urllib.request.Request(
        f"http://{config.host}:{config.port}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.api_key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        print(response.read().decode())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
