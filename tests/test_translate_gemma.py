from hy_mt_deploy.translate_gemma import (
    SmokeConfig,
    build_translation_prompt,
    ensure_model_access,
    normalize_target_language,
    run_smoke,
)
from hy_mt_deploy.service_config import OMLXConfig, load_env_file
from hy_mt_deploy.restart_policy import should_restart


def test_build_translation_prompt_uses_translation_only_format() -> None:
    prompt = build_translation_prompt(
        source_text="It is a pleasure to meet you.",
        target_language="Chinese",
    )

    assert prompt.startswith("<｜hy_begin▁of▁sentence｜><｜hy_User｜>")
    assert "只需要输出翻译后的结果" in prompt
    assert "It is a pleasure to meet you." in prompt
    assert prompt.endswith("It is a pleasure to meet you.<｜hy_place▁holder▁no▁8｜>")


def test_smoke_config_defaults_to_translategemma_model() -> None:
    cfg = SmokeConfig.from_args(["--text", "hello"])
    assert cfg.model_id == "tencent/HY-MT1.5-1.8B"


def test_normalize_target_language_maps_common_names() -> None:
    assert normalize_target_language("Chinese") == "中文"
    assert normalize_target_language("English") == "英语"


def test_load_env_file_reads_simple_key_values(tmp_path) -> None:
    env_file = tmp_path / "omlx.env"
    env_file.write_text("OMLX_PORT=8123\nOMLX_API_KEY=test-key\n", encoding="utf-8")

    result = load_env_file(env_file)

    assert result == {
        "OMLX_PORT": "8123",
        "OMLX_API_KEY": "test-key",
    }


def test_omlx_config_uses_project_defaults(tmp_path) -> None:
    root = tmp_path
    cfg = OMLXConfig.from_env(root=root, env={})

    assert cfg.model_dir == root / "models"
    assert cfg.host == "127.0.0.1"
    assert cfg.port == 8001
    assert cfg.api_key == "local-hy-key"
    assert cfg.base_path == root / ".runtime" / "omlx"


def test_omlx_config_resolves_relative_paths(tmp_path) -> None:
    root = tmp_path
    cfg = OMLXConfig.from_env(
        root=root,
        env={"OMLX_MODEL_DIR": "models-alt", "OMLX_BASE_PATH": ".state/omlx"},
    )

    assert cfg.model_dir == root / "models-alt"
    assert cfg.base_path == root / ".state" / "omlx"


def test_should_restart_when_last_restart_exceeds_threshold() -> None:
    assert should_restart(now=200, last_restart_at=100, threshold_seconds=60) is True


def test_should_not_restart_when_within_threshold() -> None:
    assert should_restart(now=150, last_restart_at=100, threshold_seconds=60) is False


def test_run_smoke_invokes_generator_with_built_prompt() -> None:
    calls = {}

    def fake_runner(*, model_id: str, prompt: str, max_tokens: int) -> str:
        calls["model_id"] = model_id
        calls["prompt"] = prompt
        calls["max_tokens"] = max_tokens
        return "\u4f60\u597d"

    cfg = SmokeConfig.from_args(
        ["--text", "Hello", "--target-language", "Chinese", "--max-tokens", "64"]
    )

    result = run_smoke(cfg, runner=fake_runner, access_checker=lambda _cfg: None)

    assert result == "\u4f60\u597d"
    assert calls["model_id"] == "tencent/HY-MT1.5-1.8B"
    assert "将以下文本翻译为中文" in calls["prompt"]
    assert "Hello" in calls["prompt"]
    assert calls["prompt"].endswith("Hello<｜hy_place▁holder▁no▁8｜>")
    assert calls["max_tokens"] == 64


def test_ensure_model_access_checks_downloadable_file(monkeypatch) -> None:
    captured = {}

    def fake_download(repo_id: str, filename: str) -> str:
        captured["repo_id"] = repo_id
        captured["filename"] = filename
        return "/tmp/config.json"

    monkeypatch.setattr(
        "hy_mt_deploy.translate_gemma.hf_hub_download",
        fake_download,
    )

    ensure_model_access(SmokeConfig.from_args(["--text", "hello"]))

    assert captured == {
        "repo_id": "tencent/HY-MT1.5-1.8B",
        "filename": "config.json",
    }


def test_ensure_model_access_skips_hf_check_for_local_model_dir(tmp_path) -> None:
    model_dir = tmp_path / "model"
    model_dir.mkdir()
    (model_dir / "config.json").write_text("{}", encoding="utf-8")

    cfg = SmokeConfig.from_args(["--text", "hello", "--model-id", str(model_dir)])

    ensure_model_access(cfg)


def test_smoke_cli_main_returns_error_code_for_runtime_error(
    monkeypatch, capsys
) -> None:
    from hy_mt_deploy.cli import main

    monkeypatch.setattr(
        "hy_mt_deploy.cli.run_smoke",
        lambda _config: (_ for _ in ()).throw(RuntimeError("login required")),
    )

    exit_code = main(["--text", "hello"])

    captured = capsys.readouterr()
    assert exit_code == 1
    assert "login required" in captured.err
