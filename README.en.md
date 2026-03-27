# Glint

<p align="center">
  <img src="docs/assets/glint-logo.png" alt="Glint logo" width="160" />
</p>

Glint is a macOS local translation app that talks to a local
OpenAI-compatible translation backend. This repository currently ships
`oMLX + HY-MT` as the default in-repo implementation.

[中文](README.md) | [English](README.en.md)

> This project is maintained primarily for personal use. There is no
> ready-to-download release build at the moment.
> If you want to use Glint, please build the app and set up the local backend
> yourself.

<p align="center">
  <img src="docs/assets/glint-screenshot.png" alt="Glint screenshot" />
</p>

<p align="center">
  <img src="docs/assets/glint-ocr-demo.gif" alt="Glint OCR demo" />
</p>

<p align="center">
  <a href="docs/assets/glint-ocr-demo.mp4">View the original OCR demo video</a>
</p>

## Product Overview

Glint is a menu bar translation utility for macOS. It supports clipboard
translation, selection translation, shortcut customization, and local backend
status management. It is meant for users who want to control their own model,
service, and runtime environment.

Current default stack:

- `Glint` handles the macOS menu bar experience and translation entry points
- `oMLX` provides the local service layer
- `HY-MT1.5-1.8B-4bit` is the current default model

## Quick Start

The steps below use the **only backend path currently shipped and verified in
this repository**: `oMLX + HY-MT`.

```bash
uv sync
cp configs/omlx.env.example configs/omlx.env
mkdir -p models/HY-MT1.5-1.8B-4bit
zsh scripts/start_omlx_tmux.sh
zsh scripts/status_omlx.sh
open mac-app/HYMTQuickTranslate/Glint.xcodeproj
```

If you want to verify the CLI path first:

```bash
uv run python scripts/repl_translate.py
```

If you want to build the macOS app directly:

```bash
zsh scripts/build_mac_app.sh
```

## macOS App

### Run Glint

1. Open `mac-app/HYMTQuickTranslate/Glint.xcodeproj`.
2. Make sure the local `oMLX` service is running at `http://127.0.0.1:8001`.
3. Run the `Glint` scheme.
4. Use the menu bar item to trigger translation or configure shortcuts.

### Menu Bar Features

- The menu shows backend status so you can see whether translation is usable.
- `Start Service`, `Stop Service`, `Restart Service`, and `Refresh Status`
  manage the local backend.
- `Translate Clipboard` reads text from the clipboard and opens the overlay.
- `Translate Selection` reads the current selection and tries to place the
  result near the cursor.
- Translation entries are disabled while the backend is unavailable or still
  starting.
- `Selection Shortcut` and `Clipboard Shortcut` record two separate global
  shortcuts.

### Default Shortcuts

- Clipboard: `Control + Option + Command + T`
- Selection: `Control + Option + Command + S`

### Selection and Clipboard

- Clipboard translation always reads the pasteboard and opens centered.
- Selection translation uses the macOS Accessibility API to read the current
  selection.
- The selection path tries to appear near the cursor and falls back to a
  centered overlay if needed.
- The selection path does not fall back to clipboard contents. If no supported
  selection exists, the app reports an error.

### Shortcut Configuration

- Clipboard and selection shortcuts are configured independently.
- Duplicate assignments are rejected during recording.
- Updated shortcuts are persisted and restored on next launch.

## Backend Integration

Glint is not tied to one specific backend repository. At runtime, it depends on
a local OpenAI-compatible HTTP service. For onboarding, the key question is
whether your backend matches the app contract.

### Current App Defaults

These values come from the current `AppConfig.default` in the macOS app:

- Base URL: `http://127.0.0.1:8001`
- Model: `HY-MT1.5-1.8B-4bit`
- API key: `local-hy-key`

Important: these defaults are currently hard-coded in the app, not loaded from
`configs/omlx.env` at runtime. If your backend uses different values, you also
need to update `AppConfig.swift`.

### Minimum Backend Contract

#### 1. Health check

The app checks backend availability with:

```http
GET /v1/models
Authorization: Bearer <apiKey>
```

The current implementation only requires a `2xx` response and does not depend
on a specific response body.

#### 2. Translation request

The app sends translation requests to:

```http
POST /v1/chat/completions
Authorization: Bearer <apiKey>
Content-Type: application/json
```

Minimum request example:

```json
{
  "model": "HY-MT1.5-1.8B-4bit",
  "messages": [
    {
      "role": "user",
      "content": "将以下文本翻译为中文，注意只需要输出翻译后的结果，不要额外解释：\n\nIt is a pleasure to meet you."
    }
  ],
  "max_tokens": 256,
  "temperature": 0.2
}
```

The app currently reads only this minimum response shape:

```json
{
  "choices": [
    {
      "message": {
        "content": "很高兴见到你。"
      }
    }
  ]
}
```

At minimum, a compatible backend must:

- accept the `Bearer` auth header
- return `2xx` from `GET /v1/models`
- accept `model`, `messages`, `max_tokens`, and `temperature` on
  `POST /v1/chat/completions`
- include `choices[0].message.content` in the response

### Prompt Expectations

Glint currently wraps translation input with this prompt format:

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

A compatible backend therefore needs to handle this single-turn Chinese
instruction-style translation prompt reliably and return only the translated
text.

## Default Backend In This Repo

This repository currently ships and verifies only one backend path:
`oMLX + HY-MT`. Concretely, the repo provides:

- `configs/omlx.env`
- `scripts/start_omlx*.sh`
- `scripts/stop_omlx.sh`
- `scripts/restart_omlx.sh`
- `scripts/status_omlx.sh`
- `scripts/api_smoke.py`
- `scripts/smoke_cli.py`
- `scripts/smoke_suite.py`

The repo does **not** provide:

- startup scripts for alternative backends
- config templates for alternative backends
- multi-backend switching
- runtime-configurable `baseURL`, `model`, or `apiKey`

If you only want the default supported workflow, continue with the `oMLX`
setup below.

### oMLX Default Implementation

Glint's default supported backend path uses a local `oMLX` service. Service
settings live in `configs/omlx.env`, which you can copy from the example file:

```bash
cp configs/omlx.env.example configs/omlx.env
```

Start the service:

```bash
zsh scripts/start_omlx.sh
```

Stop the service:

```bash
zsh scripts/stop_omlx.sh
```

Check status:

```bash
zsh scripts/status_omlx.sh
```

If you use the macOS LaunchAgent:

```bash
zsh scripts/install_omlx_launch_agent.sh
zsh scripts/start_omlx_launch_agent.sh
zsh scripts/status_omlx_launch_agent.sh
```

Corresponding stop, restart, and uninstall scripts also live under `scripts/`.

## Bring Your Own Backend

If you want to connect Glint to a different local backend instead of the
in-repo `oMLX` path, use this checklist:

- the backend listens on the current app defaults, or you have updated
  `AppConfig.swift`
- the backend accepts `Authorization: Bearer <apiKey>`
- `GET /v1/models` returns `2xx`
- `POST /v1/chat/completions` accepts the current request fields
- the response includes `choices[0].message.content`
- the model handles the current translation prompt and returns only the
  translated text

If those conditions hold, Glint should be able to reuse the same app-side
interaction flow. But the important scope boundary is unchanged:
**this repository only ships scripts and verified setup for `oMLX + HY-MT`.**

### Verification Commands

CLI smoke test:

```bash
uv run python scripts/smoke_cli.py \
  --model-id ./models/HY-MT1.5-1.8B-4bit \
  --text "It is a pleasure to meet you." \
  --target-language 中文 \
  --max-tokens 64
```

Expected output:

```text
很高兴能见到您。
```

Full smoke suite:

```bash
uv run python scripts/smoke_suite.py
```

OpenAI-compatible API smoke test:

```bash
python3 scripts/api_smoke.py
```

## Model And Prompt

Recommended local model directory:

- `models/HY-MT1.5-1.8B-4bit`

Download sources:

- `mlx-community/HY-MT1.5-1.8B-4bit`
- `tencent/HY-MT1.5-1.8B`

At minimum, place these files into `models/HY-MT1.5-1.8B-4bit/`:

- `model.safetensors`
- `config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `special_tokens_map.json`

The default in-repo backend implementation follows the official HY-MT
translation prompt format:

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

Recommended inference settings:

- `top_k: 20`
- `top_p: 0.6`
- `repetition_penalty: 1.05`
- `temperature: 0.7`

## Project Layout

- CLI environment: `.venv`
- oMLX environment: `.venv-omlx`
- Model path: `models/HY-MT1.5-1.8B-4bit`
- Local service overrides: `configs/omlx.env`
- Glint app: `mac-app/HYMTQuickTranslate/Glint.xcodeproj`

## Upstream

- oMLX repository: https://github.com/jundot/omlx
- Tencent Hunyuan HY-MT: https://github.com/Tencent-Hunyuan/HY-MT
- MLX community model: https://huggingface.co/mlx-community/HY-MT1.5-1.8B-4bit
