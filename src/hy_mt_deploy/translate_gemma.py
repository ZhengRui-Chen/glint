"""HY-MT CLI helpers."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from huggingface_hub import hf_hub_download
from mlx_lm import generate, load


DEFAULT_MODEL_ID = "tencent/HY-MT1.5-1.8B"
HY_BOS = "<｜hy_begin▁of▁sentence｜>"
HY_USER = "<｜hy_User｜>"
HY_TURN_END = "<｜hy_place▁holder▁no▁8｜>"
LANGUAGE_ALIASES = {
    "chinese": "中文",
    "中文": "中文",
    "english": "英语",
    "英语": "英语",
}


def normalize_target_language(target_language: str) -> str:
    return LANGUAGE_ALIASES.get(target_language.strip().lower(), target_language)


def build_translation_prompt(source_text: str, target_language: str) -> str:
    normalized_target_language = normalize_target_language(target_language)
    instruction = (
        f"将以下文本翻译为{normalized_target_language}，注意只需要输出翻译后的结果，不要额外解释：\n\n"
        f"{source_text}"
    )
    return f"{HY_BOS}{HY_USER}{instruction}{HY_TURN_END}"


@dataclass(slots=True)
class SmokeConfig:
    text: str
    target_language: str
    model_id: str = DEFAULT_MODEL_ID
    max_tokens: int = 256
    check_access: bool = False

    @classmethod
    def from_args(cls, argv: list[str]) -> "SmokeConfig":
        parser = argparse.ArgumentParser(
            description="Minimal CLI smoke test for TranslateGemma on MLX."
        )
        parser.add_argument("--text", required=True, help="Source text to translate.")
        parser.add_argument(
            "--target-language",
            default="中文",
            help="Natural-language target language name.",
        )
        parser.add_argument(
            "--model-id",
            default=DEFAULT_MODEL_ID,
            help="Hugging Face model id or local MLX model directory.",
        )
        parser.add_argument(
            "--max-tokens",
            type=int,
            default=256,
            help="Maximum new tokens to generate.",
        )
        parser.add_argument(
            "--check-access",
            action="store_true",
            help="Only verify Hugging Face access to the gated model.",
        )
        args = parser.parse_args(argv)
        return cls(
            text=args.text,
            target_language=args.target_language,
            model_id=args.model_id,
            max_tokens=args.max_tokens,
            check_access=args.check_access,
        )


def ensure_model_access(config: SmokeConfig) -> None:
    model_path = Path(config.model_id).expanduser()
    if model_path.exists():
        if not (model_path / "config.json").exists():
            raise RuntimeError(
                f"Local model directory is missing config.json: {model_path}"
            )
        return

    try:
        hf_hub_download(config.model_id, "config.json")
    except Exception as exc:  # pragma: no cover - external API error details vary
        raise RuntimeError(
            "Failed to access the model. Make sure you accepted the Hugging Face "
            "terms if required and ran `huggingface-cli login` for "
            "tencent/HY-MT1.5-1.8B."
        ) from exc


def mlx_runner(*, model_id: str, prompt: str, max_tokens: int) -> str:
    model, tokenizer = load(model_id)
    return generate(
        model,
        tokenizer,
        prompt=prompt,
        max_tokens=max_tokens,
        verbose=False,
    )


def run_smoke(
    config: SmokeConfig,
    *,
    runner: Callable[[str, str, int], str] | Callable[..., str] = mlx_runner,
    access_checker: Callable[[SmokeConfig], None] = ensure_model_access,
) -> str:
    access_checker(config)
    if config.check_access:
        return f"Access OK: {config.model_id}"

    prompt = build_translation_prompt(
        source_text=config.text,
        target_language=config.target_language,
    )
    return runner(
        model_id=config.model_id,
        prompt=prompt,
        max_tokens=config.max_tokens,
    )
