from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from hy_mt_deploy.service_config import OMLXConfig, load_env_file
from hy_mt_deploy.restart_policy import should_restart

THRESHOLD_SECONDS = 24 * 60 * 60
SESSION_NAME = "hy-omlx"


def read_last_restart_at(path: Path) -> int | None:
    if not path.exists():
        return None
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except ValueError:
        return None


def write_last_restart_at(path: Path, timestamp: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(timestamp), encoding="utf-8")


def is_service_running(root: Path) -> bool:
    result = subprocess.run(
        ["pgrep", "-f", f"omlx serve --model-dir {root / 'models'}"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def run_script(script_name: str) -> None:
    subprocess.run(["zsh", str(ROOT / "scripts" / script_name)], check=True)


def main() -> int:
    env = load_env_file(ROOT / "configs" / "omlx.env")
    config = OMLXConfig.from_env(root=ROOT, env=env)
    state_file = config.base_path / "last_restart_at"
    now = int(time.time())
    last_restart_at = read_last_restart_at(state_file)
    running = is_service_running(ROOT)

    if last_restart_at is None:
        if running:
            write_last_restart_at(state_file, now)
            print("Initialized restart timestamp from running service.")
            return 0
        run_script("start_omlx_tmux.sh")
        write_last_restart_at(state_file, now)
        print("Service was down. Started oMLX and wrote restart timestamp.")
        return 0

    if not running:
        run_script("start_omlx_tmux.sh")
        write_last_restart_at(state_file, now)
        print("Service was down. Started oMLX and refreshed restart timestamp.")
        return 0

    if should_restart(
        now=now,
        last_restart_at=last_restart_at,
        threshold_seconds=THRESHOLD_SECONDS,
    ):
        run_script("restart_omlx.sh")
        write_last_restart_at(state_file, now)
        print("Restarted oMLX after threshold.")
        return 0

    print("No restart required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
