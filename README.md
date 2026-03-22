# HY-MT MLX PoC

Minimal `uv`-managed local deployment for `HY-MT1.5-1.8B-4bit` on Apple Silicon.

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
