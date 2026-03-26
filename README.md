# HY-MT MLX PoC

Minimal `uv`-managed local deployment for `HY-MT1.5-1.8B-4bit` on Apple Silicon.

I mainly use this setup with Immersive Translate on my local Mac. The response speed feels very fast, and the overall experience is surprisingly good for a fully local translation workflow.

This project uses `oMLX` as the local serving layer. `oMLX` is a relatively new Apple Silicon focused inference framework that exposes MLX models through an OpenAI-compatible API, which makes it a good fit for serving HY-MT as a local translation service.

oMLX repository:

- https://github.com/jundot/omlx

## Model Download

Recommended MLX model:

- `mlx-community/HY-MT1.5-1.8B-4bit`
- https://huggingface.co/mlx-community/HY-MT1.5-1.8B-4bit

Original Tencent model:

- `tencent/HY-MT1.5-1.8B`
- https://huggingface.co/tencent/HY-MT1.5-1.8B

Upstream project:

- Tencent Hunyuan HY-MT
- https://github.com/Tencent-Hunyuan/HY-MT

Create the local model directory:

```bash
mkdir -p models/HY-MT1.5-1.8B-4bit
```

At minimum, place these files into `models/HY-MT1.5-1.8B-4bit/`:

- `model.safetensors`
- `config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `special_tokens_map.json`

## Layout

- CLI environment: `.venv`
- oMLX environment: `.venv-omlx`
- Project model path: `models/HY-MT1.5-1.8B-4bit`
- Local service overrides: `configs/omlx.env` (copy from `configs/omlx.env.example`)

## CLI Smoke Test

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

## Smoke Suite

```bash
uv run python scripts/smoke_suite.py
```

## Quick Start

```bash
uv sync
cp configs/omlx.env.example configs/omlx.env
zsh scripts/start_omlx_tmux.sh
zsh scripts/status_omlx.sh
uv run python scripts/repl_translate.py
```

## oMLX Serve

```bash
./scripts/start_omlx.sh
```

Service settings live in `configs/omlx.env`.
Initialize local config from the example:

```bash
cp configs/omlx.env.example configs/omlx.env
```

Stop the service:

```bash
./scripts/stop_omlx.sh
```

Check status:

```bash
./scripts/status_omlx.sh
```

## OpenAI-Compatible API Smoke Test

```bash
python3 scripts/api_smoke.py
```

## Interactive Translation REPL

```bash
uv run python scripts/repl_translate.py
```

Example:

```text
direction[en2zh/zh2en] (default: en2zh)>
src> It is a pleasure to meet you.
out> 很高兴能见到您。
```

## curl Example

```bash
curl http://127.0.0.1:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer local-hy-key" \
  -d '{
    "model": "HY-MT1.5-1.8B-4bit",
    "messages": [
      {
        "role": "user",
        "content": "将以下文本翻译为中文，注意只需要输出翻译后的结果，不要额外解释：\n\nIt is a pleasure to meet you."
      }
    ],
    "max_tokens": 64,
    "temperature": 0.2
  }'
```

## Prompt Notes

This project follows the official Tencent HY-MT prompt pattern for `ZH <=> XX` translation:

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

The original HY-MT README also recommends these inference settings:

- `top_k: 20`
- `top_p: 0.6`
- `repetition_penalty: 1.05`
- `temperature: 0.7`

## macOS Quick Translate App

An Xcode macOS companion app now lives under `mac-app/HYMTQuickTranslate/`.
The initial target wires the local service defaults and will be expanded in
later tasks for clipboard translation and floating overlay presentation.

### Run the macOS app

1. Open `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj` in Xcode.
2. Make sure the local `oMLX` service is running and reachable at
   `http://127.0.0.1:8001`.
3. Run the `HYMTQuickTranslate` scheme on your Mac.
4. Copy text to the clipboard and press the default shortcut:
   `Control + Option + Command + T`

You can start the local service with:

```bash
cp configs/omlx.env.example configs/omlx.env
zsh scripts/start_omlx_tmux.sh
zsh scripts/status_omlx.sh
```

Threshold behavior:

- `<= 2000` characters: translate immediately
- `2001...8000` characters: ask for confirmation in the floating panel
- `> 8000` characters: reject the request with an error message

## Acknowledgements

Thanks to:

- Tencent Hunyuan team for releasing `HY-MT1.5-1.8B` and the official prompt guidance
- `mlx-community` for the `HY-MT1.5-1.8B-4bit` MLX conversion
- `oMLX` for the local OpenAI-compatible serving layer
