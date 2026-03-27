# Backend API-Only Design

**Goal:** Simplify Glint into a pure API client by removing backend mode
switching and all local service lifecycle management from the macOS app.

## Why This Change

The current runtime backend settings work introduced one incorrect assumption:
the app still tries to own backend deployment shape.

That shows up in three ways:

- backend settings mix API identity with deployment mode
- the app exposes `Start`, `Stop`, and `Restart` for a local service it does not
  reliably control
- runtime composition couples translation requests, API health checks, process
  checks, and shell-script lifecycle actions

This is a responsibility mismatch. Even if Glint originally targeted a local
`HY` workflow, the app is now better positioned as a general translation client
for any OpenAI-compatible backend.

## Product Decisions

### Glint is API-only

Glint should only know how to:

- store connection settings
- send translation requests
- run an explicit backend connectivity check
- display the last known status

Glint should not know how to:

- start a local inference service
- stop a local inference service
- restart a local inference service
- infer whether a local process is running

### One backend shape

The app should have one backend configuration model only:

- `baseURL`
- `model`
- `apiKey`

There is no `mode`.

Any backend, local or remote, is treated the same way as long as it exposes the
expected HTTP API.

### Popup panel stays

The dedicated backend popup panel remains the right UI abstraction. It should
continue to reuse the shortcut settings panel style, but now the form becomes
smaller and clearer:

- `Base URL`
- `Model`
- `API Key`
- `Check Backend`
- `Reset to Defaults`
- `Done`

The panel should no longer show:

- mode selection
- `Start Service`
- `Stop Service`
- `Restart Service`

### Explicit checks only

Backend status checks remain on-demand only:

- after `Done` when settings changed
- after `Check Backend`

There is no background polling and no preflight check before translation.

## Data Model

### Backend settings

`BackendSettings` should be reduced to API fields only:

- `baseURL`
- `model`
- `apiKey`

Persistence should remain `UserDefaults`-based so the settings panel stays
lightweight and immediately applicable.

### Migration

Existing saved settings from the previous runtime-settings build may still
contain a `mode` field. Migration should be automatic:

- decode legacy payloads that contain `mode`
- preserve the stored `baseURL`, `model`, and `apiKey`
- ignore the legacy `mode`
- fall back to defaults only if decoding cannot recover API fields

This prevents users from losing an already-configured remote backend.

## Runtime Composition

`BackendRuntime` should only compose:

- `AppConfig`
- `TranslationClient`
- `BackendStatusMonitor`

It should not expose a control service.

The status monitor should only check API reachability. Local process inspection
is removed.

## Menu Architecture

The native menu keeps:

- translation actions
- `Backend...`
- keyboard shortcuts
- accessibility status
- quit

The menu should no longer carry hidden assumptions about local service actions.

## Testing Strategy

Add or update tests for:

- legacy backend settings migration
- backend panel draft/save/reset behavior without mode controls
- runtime rebuild after saving API settings
- absence of local service actions in menu and panel
- explicit backend checks after save and manual check only

Manual validation should continue to use local environment variables for remote
credentials only. No real secret should be written to files or git history.

## Acceptance Criteria

- app backend settings are API-only
- legacy saved settings migrate automatically without losing API fields
- no mode selector exists in the app
- no local service lifecycle actions exist in the app
- backend status depends only on explicit API checks
- local and remote backends are both treated as OpenAI-compatible APIs
