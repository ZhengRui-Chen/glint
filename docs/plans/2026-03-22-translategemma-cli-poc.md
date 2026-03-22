# TranslateGemma CLI PoC Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a clean `uv`-managed local project that can validate `google/TranslateGemma-4b-it` access and run a minimal text-translation CLI smoke test on Apple Silicon Mac.

**Architecture:** Use a fresh `uv` project with a small Python package and a CLI smoke script. Keep the first milestone narrow: prompt construction, gated-model access checks, and one-shot local CLI invocation wiring. Defer `oMLX` service integration until the CLI path is verified.

**Tech Stack:** `uv`, Python 3.11, `pytest`, `mlx-lm`, `huggingface_hub`, `transformers`

---

### Task 1: Create project skeleton and tests

**Files:**
- Create: `pyproject.toml`
- Create: `src/hy_mt_deploy/__init__.py`
- Create: `src/hy_mt_deploy/translate_gemma.py`
- Create: `tests/test_translate_gemma.py`

**Step 1: Write the failing test**

```python
from hy_mt_deploy.translate_gemma import build_translation_prompt


def test_build_translation_prompt_uses_translation_only_format():
    prompt = build_translation_prompt(
        source_text="It is a pleasure to meet you.",
        target_language="Chinese",
    )
    assert "without additional explanation" in prompt
    assert prompt.endswith("It is a pleasure to meet you.")
```

**Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: FAIL with import error or missing function.

**Step 3: Write minimal implementation**

```python
def build_translation_prompt(source_text: str, target_language: str) -> str:
    return (
        f"Translate the following segment into {target_language}, "
        "without additional explanation.\n\n"
        f"{source_text}"
    )
```

**Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: PASS

### Task 2: Add CLI argument parsing and Hugging Face access preflight

**Files:**
- Modify: `src/hy_mt_deploy/translate_gemma.py`
- Create: `scripts/smoke_cli.py`
- Modify: `tests/test_translate_gemma.py`

**Step 1: Write the failing test**

```python
from hy_mt_deploy.translate_gemma import SmokeConfig


def test_smoke_config_defaults_to_translategemma_model():
    cfg = SmokeConfig.from_args(["--text", "hello"])
    assert cfg.model_id == "google/TranslateGemma-4b-it"
```

**Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: FAIL with missing class or parser.

**Step 3: Write minimal implementation**

```python
@dataclass
class SmokeConfig:
    ...
```

**Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: PASS

### Task 3: Verify CLI execution path without forcing model download in tests

**Files:**
- Modify: `src/hy_mt_deploy/translate_gemma.py`
- Modify: `tests/test_translate_gemma.py`

**Step 1: Write the failing test**

```python
def test_run_smoke_invokes_generator_with_built_prompt(monkeypatch):
    ...
```

**Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: FAIL because the orchestration function does not exist.

**Step 3: Write minimal implementation**

```python
def run_smoke(...):
    ...
```

**Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: PASS

### Task 4: Set up fresh uv environment and run verification

**Files:**
- Create: `.python-version`
- Create: `README.md`

**Step 1: Sync environment**

Run: `uv sync`
Expected: virtualenv created with locked dependencies.

**Step 2: Run focused tests**

Run: `uv run pytest tests/test_translate_gemma.py -v`
Expected: PASS

**Step 3: Run CLI help**

Run: `uv run python scripts/smoke_cli.py --help`
Expected: argparse help renders.

**Step 4: Run gated-model preflight**

Run: `uv run python scripts/smoke_cli.py --check-access --text "hello"`
Expected: either successful access confirmation or a clear gated-model error instructing the user to accept the Hugging Face license.
