# macOS Quick Translate Design

**Date:** 2026-03-26

**Status:** Approved

**Goal:** Add a lightweight native macOS companion app that lets the user press a global shortcut, read plain text from the clipboard, translate it through the existing local `oMLX` service, and show the result in a temporary floating window.

## Scope

The first release stays deliberately narrow:

- Native macOS app built with Swift
- Global shortcut trigger
- Clipboard text input only
- Auto-detect `en2zh` vs `zh2en` with simple heuristics
- Length thresholds with confirmation for medium-sized input
- Temporary floating panel for loading, confirmation, result, and errors
- Direct requests to the existing local OpenAI-compatible translation API

The first release explicitly does not include:

- Menu bar app behavior as the primary interaction
- Accessibility-based selected-text capture
- Python relay or middleware
- Embedded model inference inside the macOS app
- History, settings UI, manual direction switch, or auto-copy result

## Why This Shape

The repository already provides a local translation service and helper scripts. The missing piece is a low-friction macOS interaction layer, not another backend. The fastest path with the cleanest responsibilities is:

- Swift app handles UX and OS integration
- Existing `oMLX` service remains the translation backend

This keeps the hot path simple:

`global shortcut -> Swift app -> localhost API -> translation result -> floating panel`

## Architecture

### Existing Boundary

The current project already exposes a local OpenAI-compatible API, documented in:

- `README.md`
- `scripts/api_smoke.py`
- `scripts/repl_translate.py`

That service should remain the only translation backend for the macOS app.

### New Companion App Boundary

Add a new macOS-only subtree:

```text
mac-app/
  HYMTQuickTranslate/
    HYMTQuickTranslate.xcodeproj
    HYMTQuickTranslate/
    HYMTQuickTranslateTests/
```

The app owns:

- Global shortcut registration
- Clipboard read
- Direction detection
- Length threshold policy
- HTTP request construction
- Temporary panel presentation
- Error messaging

## User Flow

1. User copies text to the clipboard.
2. User presses a global shortcut.
3. App reads plain text from the clipboard.
4. App validates empty content and length policy.
5. App detects translation direction.
6. App calls `http://127.0.0.1:8001/v1/chat/completions`.
7. App shows one temporary floating panel:
   - loading state
   - optional long-text confirmation
   - translated result
   - error state
8. User dismisses the panel by clicking away or pressing `Esc`.

## Direction Detection

The first release uses a simple heuristic instead of a language ID model.

Ignore these when counting signal:

- whitespace
- punctuation
- digits
- URLs
- email addresses
- symbols

Count these signals:

- Han characters
- Latin letters

Decision rule:

```text
if hanCount >= 2 and hanCount > latinCount:
    zh2en
elif latinCount >= 3 and latinCount > hanCount:
    en2zh
else:
    fallback = en2zh
```

This is intentionally biased toward the likely use case of translating copied English text into Chinese when the signal is weak.

## Length Policy

Use a two-threshold policy:

- `<= 2000` characters: translate immediately
- `2001...8000` characters: show confirmation before translating
- `> 8000` characters: reject with a clear message

This prevents accidental slow requests and keeps the quick-translate surface aligned with short clipboard snippets.

## API Contract

The macOS app should call the local OpenAI-compatible endpoint directly.

Defaults:

- Base URL: `http://127.0.0.1:8001`
- Path: `/v1/chat/completions`
- Model: `HY-MT1.5-1.8B-4bit`
- Timeout: `20s`

Prompt contract mirrors the existing scripts:

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

Expected response extraction:

- `choices[0].message.content`

## Floating Panel Behavior

Use a lightweight `NSPanel` or equivalent AppKit-backed floating window.

Desired behavior:

- Appears centered or near the active screen center
- Shows one state at a time
- Accepts `Esc` to close
- Closes when focus is lost
- Does not become a heavy persistent window

States:

- `loading`
- `confirmLongText`
- `result`
- `error`

The confirmation state should reuse the same panel instead of opening a second modal window.

## Error Handling

The app should surface simple, explicit messages for:

- clipboard has no translatable text
- text exceeds hard limit
- local translation service unavailable
- request timeout
- invalid API response

No retries are required in the first release.

## Configuration

The first release should keep configuration minimal and code-local:

- base URL
- model name
- soft limit
- hard limit
- timeout
- fallback direction

No settings UI is needed initially.

## Testing Strategy

### Unit Tests

Add deterministic tests for:

- direction detection
- threshold policy
- request payload construction
- API response parsing

### Integration Checks

Verify against the local running service:

- English clipboard text returns Chinese output
- Chinese clipboard text returns English output
- medium-length text triggers confirmation
- service-down path shows an error state

### Manual UX Checks

Confirm:

- shortcut triggers reliably
- panel dismisses on click-away and `Esc`
- no duplicate panels accumulate

## Risks and Deferred Work

Known risks:

- Global shortcut implementation details differ between pure SwiftUI and AppKit-backed wiring
- Very mixed Chinese-English clipboard text may choose the less useful direction
- If the local service is not running, the app depends entirely on clear error messaging

Deferred work:

- menu bar entry point
- settings screen
- translation history
- selected-text capture via Accessibility APIs
- result copy button
- configurable shortcut
