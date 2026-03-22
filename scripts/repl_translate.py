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
from hy_mt_deploy.translate_gemma import normalize_target_language


def translate(text: str, target_language: str, config: OMLXConfig) -> str:
    normalized_target_language = normalize_target_language(target_language)
    payload = {
        "model": "HY-MT1.5-1.8B-4bit",
        "messages": [
            {
                "role": "user",
                "content": (
                    f"将以下文本翻译为{normalized_target_language}，"
                    "注意只需要输出翻译后的结果，不要额外解释：\n\n"
                    f"{text}"
                ),
            }
        ],
        "max_tokens": 256,
        "temperature": 0.2,
    }
    request = urllib.request.Request(
        f"http://{config.host}:{config.port}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.api_key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        body = json.loads(response.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"]


def main() -> int:
    env = load_env_file(ROOT / "configs" / "omlx.env")
    config = OMLXConfig.from_env(root=ROOT, env=env)
    direction = (input("direction[en2zh/zh2en] (default: en2zh)> ").strip() or "en2zh").lower()
    if direction not in {"en2zh", "zh2en"}:
        print("Unsupported direction, use en2zh or zh2en.")
        return 1
    target_language = "中文" if direction == "en2zh" else "English"

    while True:
        try:
            text = input("src> ").strip()
        except EOFError:
            print()
            break
        if text.lower() in {"exit", "quit"}:
            break
        if not text:
            continue
        print(f"out> {translate(text, target_language, config)}")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
