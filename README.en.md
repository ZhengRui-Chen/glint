# Glint

<p align="center">
  <img src="docs/assets/glint-logo.png" alt="Glint logo" width="160" />
</p>

Glint is a macOS menu bar translation client.

[中文](README.md) | [English](README.en.md)

<p align="center">
  <img src="docs/assets/glint-screenshot.png" alt="Glint screenshot" />
</p>

<p align="center">
  <img src="docs/assets/glint-ocr-demo.gif" alt="Glint OCR demo" />
</p>

<p align="center">
  <a href="docs/assets/glint-ocr-demo.mp4">View the original OCR demo video</a>
</p>

## Scope

Glint handles the macOS client experience only:

- menu bar integration
- clipboard translation
- selection translation
- OCR region translation
- shortcut customization
- translation provider settings

Glint ** no longer owns ** model downloads, service startup, watchdogs, or
local deployment scripts.

For the backend repository I use with Glint, see:

- `https://github.com/ZhengRui-Chen/HY-MT`

## Translation Providers

Glint now supports two translation modes:

- `Custom API`
- `System Translation`

### Custom API

`Custom API` is for your own compatible endpoint. Glint currently uses:

- `POST /v1/chat/completions`
- `GET /v1/models`

`/v1/models` is only used for model discovery.
If your backend does not expose it, you can still type the model name manually.

### System Translation

`System Translation` uses the translation capability built into macOS and does
not require:

- `Base URL`
- `API Key`
- `Model`

This mode depends on system translation support and installed language data.
The settings panel shows the current availability state directly.

## macOS App

### Run

1. Open `mac-app/Glint.xcodeproj`
2. Run the `Glint` scheme
3. Open `API Settings…` from the menu bar
4. Choose a translation mode:
   - `Custom API`: configure `Base URL`, `API Key`, and `Model`
   - `System Translation`: use macOS translation directly

You can also build the app directly:

```bash
zsh scripts/build_mac_app.sh
```

If you want a plain distributable DMG:

```bash
zsh scripts/build_dmg.sh
```

The output will be written to `dist/Glint.dmg`.

### API Settings

The `API Settings…` panel now has two tabs:

- `Custom API`
- `System Translation`

Notes:

- `Custom API` exposes `Base URL`, `API Key`, and `Model`
- `Model` supports both manual entry and dropdown selection after refreshing `/v1/models`
- `System Translation` shows the current system translation availability
- settings are persisted in `UserDefaults`

### Menu Bar Features

- the menu shows the current translation provider status
- `Refresh Status` re-checks `Custom API` connectivity
- `Translate Clipboard` reads from the pasteboard
- `Translate Selection` reads the current selection and tries to place results near the cursor
- `Translate OCR Area` lets you capture a screen region, run OCR, then translate
- `Keyboard Shortcuts…` records global shortcuts

### Default Shortcuts

- Clipboard: `Control + Option + Command + T`
- Selection: `Control + Option + Command + S`
- OCR: `Control + Option + Command + O`

## Backend Repository

Backend deployment, model management, and service operations now live in a
separate repository:

- `https://github.com/ZhengRui-Chen/HY-MT`

If you use `Custom API`, set up the backend there first, then point Glint at it
through `API Settings…`.
