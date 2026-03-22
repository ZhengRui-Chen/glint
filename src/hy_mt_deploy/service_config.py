from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


@dataclass(slots=True)
class OMLXConfig:
    model_dir: Path
    host: str
    port: int
    api_key: str
    base_path: Path

    @classmethod
    def from_env(cls, *, root: Path, env: dict[str, str]) -> "OMLXConfig":
        model_dir_value = env.get("OMLX_MODEL_DIR", "models")
        base_path_value = env.get("OMLX_BASE_PATH", str(root / ".runtime" / "omlx"))
        model_dir = Path(model_dir_value)
        if not model_dir.is_absolute():
            model_dir = root / model_dir
        base_path = Path(base_path_value)
        if not base_path.is_absolute():
            base_path = root / base_path
        return cls(
            model_dir=model_dir,
            host=env.get("OMLX_HOST", "127.0.0.1"),
            port=int(env.get("OMLX_PORT", "8001")),
            api_key=env.get("OMLX_API_KEY", "local-hy-key"),
            base_path=base_path,
        )
