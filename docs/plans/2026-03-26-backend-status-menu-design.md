# Backend Status Menu Design

**Date:** 2026-03-26

**Status:** Approved

**Goal:** Extend the macOS menu bar app so users can see whether the translation backend is usable and can manage that backend directly from the menu without exposing internal implementation details.

## User Intent

The user does not care about `tmux`, process IDs, or transport mechanics. The menu should answer only:

- can translation be used right now
- if not, what should I do next

That means the menu should look like a product surface, not an operator console.

## Scope

This change adds:

- a user-facing backend availability section near the top of the menu
- start, stop, restart, and refresh actions for the backend
- disabled translation entries when the backend is not usable
- lightweight visual polish for the backend section

This change does not add:

- menu bar badge dots or text beside the icon
- full logs or raw diagnostic output in the menu
- advanced process management UI
- changes to the backend model or translation API itself

## UX Shape

The status bar button remains the clean `Glint` icon.

When the menu opens, the first section is the backend status block:

- `Service Status: Available`
- `Translation backend is reachable`

Other states:

- `Service Status: Checking...`
- `Service Status: Starting`
- `Service Status: Unavailable`
- `Service Status: Error`

Available actions:

- `Start Service`
- `Stop Service`
- `Restart Service`
- `Refresh Status`

The translation menu items remain below this section. When the backend is not usable, `Translate Selection` and `Translate Clipboard` are disabled instead of allowing the user to click into a predictable error.

## Status Model

The app should map internal checks to a small user-facing state machine:

- `available`
- `starting`
- `unavailable`
- `error`
- transient `checking`

Internal signals may use:

- API reachability against `http://127.0.0.1:8001/v1/models`
- local process existence for the backend server
- recent user action context, such as an in-flight start or restart

User-facing rules:

- `available`: API reachable
- `starting`: recent start or restart action is still converging, or process exists while API is still warming up
- `unavailable`: backend not reachable and not in a recent transition
- `error`: command execution or status checks fail unexpectedly

The menu never displays `tmux`, command text, or raw shell errors.

## Architecture

Add a backend-specific slice inside the macOS app:

- `BackendStatusSnapshot`: immutable state for menu rendering
- `BackendStatusMonitor`: computes status snapshots from API health, process checks, and transition context
- `BackendControlService`: runs start, stop, restart, and refresh operations

`MenuBarViewModel` should become the consumer of this backend status model, not the owner of shell details.

`AppDelegate` should own one monitor and one control service, then inject derived state and actions into `MenuBarViewModel`.

## Integration Strategy

For control actions, reuse the existing repository scripts:

- `scripts/start_omlx_tmux.sh`
- `scripts/stop_omlx.sh`
- `scripts/restart_omlx.sh`

For status checks, do not parse the current human-readable `status_omlx.sh` output. Instead, keep the check logic inside the macOS app where it is easy to test deterministically:

- shell command runner for local process presence
- HTTP probe for API reachability
- timer-driven refresh plus explicit refresh on menu open

This keeps the UX stable even if shell output formatting changes.

## Refresh Behavior

The menu should refresh in two situations:

1. Immediately when the menu opens
2. Periodically in the background at a low frequency, such as every 10 to 15 seconds

When an action is running:

- show an in-progress state
- disable conflicting actions
- disable translation entries until the backend is usable again

## Visual Direction

Keep the existing AppKit menu structure, but make the backend section feel more intentional:

- a short status heading
- one succinct detail line
- grouped actions below a separator

Avoid heavy custom menu views. A few well-labeled disabled items and separators are enough to create order without fighting native menu behavior.

## Error Handling

Use short product-style language:

- `Translation backend is reachable`
- `Backend is starting, please wait`
- `Backend is currently unavailable`
- `Unable to verify backend status`
- `Failed to start the service`
- `Failed to stop the service`
- `Failed to restart the service`

Do not surface shell internals unless the user later asks for a diagnostics feature.

## Testing Strategy

Add deterministic unit tests for:

- status mapping from internal signals to user-facing state
- menu item enabled and disabled behavior by backend state
- action transitions such as start to starting to available
- preservation of existing menu functionality

Verification should include:

- `uv run pytest -q`
- `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
- `zsh scripts/build_mac_app.sh`
