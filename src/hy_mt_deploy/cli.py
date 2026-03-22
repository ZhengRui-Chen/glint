from __future__ import annotations

import sys

from hy_mt_deploy.translate_gemma import SmokeConfig, run_smoke


def main(argv: list[str] | None = None) -> int:
    config = SmokeConfig.from_args(argv or sys.argv[1:])
    try:
        print(run_smoke(config))
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0
