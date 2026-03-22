from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from hy_mt_deploy.translate_gemma import SmokeConfig, run_smoke


def main() -> int:
    model_dir = str(ROOT / "models" / "HY-MT1.5-1.8B-4bit")
    cases = [
        ("Good morning, everyone.", "中文"),
        ("谢谢你的帮助。", "English"),
        ("Please keep the <b>HTML tag</b> unchanged.", "中文"),
    ]

    for text, target_language in cases:
        config = SmokeConfig(
            text=text,
            target_language=target_language,
            model_id=model_dir,
            max_tokens=64,
        )
        result = run_smoke(config)
        print(f"SRC: {text}")
        print(f"TGT({target_language}): {result}")
        print("---")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
