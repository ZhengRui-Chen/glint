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

## LaunchAgent

Install the macOS LaunchAgent:

```bash
zsh scripts/install_omlx_launch_agent.sh
```

Start it on demand:

```bash
zsh scripts/start_omlx_launch_agent.sh
```

Stop it:

```bash
zsh scripts/stop_omlx_launch_agent.sh
```

Restart it:

```bash
zsh scripts/restart_omlx_launch_agent.sh
```

Check status:

```bash
zsh scripts/status_omlx_launch_agent.sh
```

Uninstall it:

```bash
zsh scripts/uninstall_omlx_launch_agent.sh
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

## Glint macOS App

Glint, the macOS companion app for this project, now lives under
`mac-app/HYMTQuickTranslate/`.
It provides a menu bar utility with separate clipboard and selection
translation paths backed by the local `oMLX` service.

### Run Glint

1. Open `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj` in Xcode.
2. Make sure the local `oMLX` service is running and reachable at
   `http://127.0.0.1:8001`.
3. Run the `HYMTQuickTranslate` scheme on your Mac.
4. Use the menu bar item to trigger translation or configure shortcuts.

### Menu bar usage

After launch, the app runs as a menu bar utility.

- `Translate Clipboard` reads plain text from the clipboard and shows the
  floating translation overlay.
- `Translate Selection` reads the current accessibility-exposed selection and
  shows the overlay near the cursor when possible.
- `Selection Shortcut` and `Clipboard Shortcut` let you record separate global
  hotkeys from the menu bar.
- `Cancel Shortcut Recording` exits shortcut capture mode if you start
  recording by mistake.

Default shortcuts:

- Clipboard: `Control + Option + Command + T`
- Selection: `Control + Option + Command + S`

### Clipboard vs selection triggers

- Clipboard translation always reads from the pasteboard and opens the overlay
  in the centered placement.
- Selection translation reads the current text selection through macOS
  accessibility APIs.
- Selection-triggered overlays try to appear near the cursor and safely fall
  back to centered placement if no usable anchor is available.
- The selection path does not fall back to clipboard contents. If no supported
  selection is available, the app reports an error instead.

### Shortcut configuration

- Clipboard and selection shortcuts are configured independently.
- Duplicate assignments are rejected during recording.
- Updated shortcuts are persisted and restored on the next launch.
- If a new shortcut cannot be registered with macOS, the previous active
  shortcut remains in place.

### Accessibility requirement

Selection translation requires Accessibility permission for the app.

- Without permission, the selection path reports an explicit permission error.
- The clipboard path does not require Accessibility permission.

To grant permission, open:

- `System Settings > Privacy & Security > Accessibility`

### Supported selection scenarios

Supported:

- Text selected in apps that expose `AXSelectedText` through macOS
  Accessibility APIs
- Cursor-near overlay placement when the current mouse location can be used as
  the anchor

Unsupported or limited:

- Apps that do not expose selected text through Accessibility APIs
- Empty selections or controls that only expose focus without selected text
- Exact selection-bounds anchoring; the current implementation anchors near the
  cursor rather than the selected text rect

### Quick verification checklist

Use this checklist when validating the app manually:

- menu bar is visible after launch
- clipboard and selection actions are both accessible
- two shortcuts can be configured and persisted
- selection path reports permission errors clearly
- selection path does not silently fall back to clipboard
- cursor-near placement falls back safely

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

Overlay polish notes:

- The floating panel now uses content-aware sizing for result, error, and confirmation states.
- On macOS 26 and newer, the panel adopts Liquid Glass styling for the background and primary actions.
- On older macOS versions, it falls back to the existing material-based appearance so readability stays stable.

### Build a local app bundle

If you want a fixed app bundle outside Xcode `DerivedData`, run:

```bash
zsh scripts/build_mac_app.sh
```

This exports the Glint app bundle to:

```text
dist/HYMTQuickTranslate.app
```

## Acknowledgements

Thanks to:

- Tencent Hunyuan team for releasing `HY-MT1.5-1.8B` and the official prompt guidance
- `mlx-community` for the `HY-MT1.5-1.8B-4bit` MLX conversion
- `oMLX` for the local OpenAI-compatible serving layer
