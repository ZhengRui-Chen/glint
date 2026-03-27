# Backend Runtime Settings Design

**Goal:** Make Glint's backend configurable at runtime, apply changes
immediately after save, and move backend management out of the crowded native
menu into a dedicated popup panel while avoiding unnecessary background status
checks.

## Why This Change

The current implementation is still optimized for one bundled backend path:

- backend connection settings are hard-coded in `AppConfig.default`
- the app constructs translation clients and backend monitors at startup
- the menu mixes translation actions with backend management
- backend status is refreshed on a fixed interval even when that adds no user
  value

This blocks the intended onboarding path for custom backends and creates noisy
status checks for remote paid APIs.

## Product Decisions

### Runtime configuration

Backend settings should be editable without changing Swift source. Saving
changes should immediately update the active runtime configuration.

### Two backend modes

The app should support two explicit modes:

1. `managedLocal`
2. `externalAPI`

`managedLocal` continues to support the existing `oMLX + HY-MT` workflow.
`externalAPI` is for any OpenAI-compatible endpoint that should not expose
local process controls.

### Backend-specific popup panel

The existing native menu should keep high-frequency translation actions.
Backend-related controls should move into a custom popup panel opened from a
single `Backend...` menu item.

The panel should reuse the shortcut settings panel's visual language and window
behavior so the experience stays consistent.

### On-demand status checks only

The app should stop background polling. Backend status should refresh only when
there is a real reason:

- after `Done` saves changed backend settings
- after `Check Backend`
- after `Start`, `Stop`, or `Restart`

The app should not preflight a translation request with a separate health check.
If translation fails, the failure can update the last known backend status.

## Information Architecture

### Native menu

Keep these in the native `NSMenu`:

- `Translate Selection`
- `Translate Clipboard`
- `Translate OCR`
- `Keyboard Shortcuts`
- `Quit`

Replace the current backend action cluster with:

- backend headline
- backend detail
- one `Backend...` entry

### Backend panel

The backend panel should contain four blocks:

1. header
2. mode switch
3. config form
4. action and status area

Recommended controls:

- `Mode`: `Managed Local` / `External API`
- `Base URL`
- `Model`
- `API Key`
- `Check Backend`
- `Reset to Defaults`
- `Done`

Visible only in `managedLocal`:

- `Start`
- `Stop`
- `Restart`

## Data Model

### Backend settings

Add a persisted settings model similar to `ShortcutSettings`:

- `mode`
- `baseURL`
- `model`
- `apiKey`

Requirements:

- `Codable`
- `Equatable`
- load from `UserDefaults`
- save to `UserDefaults`
- defaults for both backend modes

### Runtime composition

The app needs a runtime assembly layer that can rebuild backend dependencies
whenever settings change. That layer should provide:

- translation client
- backend status monitor
- backend control service availability

This avoids keeping stale startup-only clients after the user saves new
settings.

## Status Model

The current snapshot model should evolve to represent "last known status"
instead of "continuously refreshed status."

Recommended top-level states:

- `notChecked`
- `checking`
- `available`
- `unavailable`
- `error`

Mode-sensitive details:

- `managedLocal` may mention process state and startup transitions
- `externalAPI` should never mention local process state

## Persistence And Save Semantics

The backend panel should edit a draft copy of persisted settings.

- opening the panel loads the saved settings into draft state
- changing fields does not affect runtime immediately
- `Done` without changes closes the panel
- `Done` with changes saves settings, rebuilds runtime dependencies, triggers a
  backend check, then closes the panel
- `Check Backend` checks the currently saved settings, not unsaved draft edits
- `Reset to Defaults` resets the draft, but still requires `Done` to persist

## Testing Strategy

### Automated coverage

Add tests for:

- backend settings load/save/defaults
- backend panel draft state and change detection
- backend mode-specific action availability
- runtime rebuild after save
- removal of periodic background refresh
- menu interaction that opens the backend panel

### Manual validation

Manual validation should cover both modes:

1. managed local `oMLX`
2. external remote API

For remote validation, use local environment variables only. Do not write real
credentials into the repository, source files, docs, tests, fixtures, or git
history.

Suggested env vars:

- `SILICONFLOW_BASE_URL`
- `SILICONFLOW_API_KEY`
- `SILICONFLOW_MODEL`

The current requested remote validation target is SiliconFlow with the
user-provided credentials, but those credentials must remain local-only.

## Acceptance Criteria

- backend settings are no longer hard-coded at runtime
- saving backend settings takes effect immediately
- backend controls live in a popup panel, not a long native menu section
- local-only controls are hidden in `externalAPI` mode
- background timer-based status refresh is removed
- backend status checks happen only on explicit, necessary actions
- remote API validation can be performed using env vars without storing secrets
