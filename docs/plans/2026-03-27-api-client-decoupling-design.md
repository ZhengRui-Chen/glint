# API Client Decoupling Design

**Goal:** Refactor `Glint` into a pure macOS client for OpenAI-compatible translation APIs, move backend/model deployment concerns out of this repository, and keep runtime API configuration for `baseURL`, `apiKey`, and `model`.

## Why This Change

The repository no longer needs to own model deployment. Recent app work already
shifted translation onto an API boundary, but the codebase still carries
deployment-specific assumptions:

- hard-coded default model and API key values
- backend process probing for `omlx serve --model-dir`
- menu actions for start/stop/restart service
- Python utilities and shell scripts for local model deployment
- README guidance centered on `oMLX` and `HY-MT` setup

That coupling makes the repository harder to maintain and misstates the
product boundary. The user wants `Glint` to remain the app they use day to day
while the concrete backend stack moves into a separate repository:

- Backend repository: `https://github.com/ZhengRui-Chen/HY-MT`

## Product Boundary After Refactor

### Glint keeps

- macOS menu bar app
- clipboard, selection, and OCR translation flows
- shortcut management
- API reachability status
- editable runtime API settings:
  - `baseURL`
  - `apiKey`
  - `model`
- model discovery through `GET /v1/models`

### Glint removes

- backend process management
- start/stop/restart service menu actions
- `oMLX` process heuristics
- local model directory conventions
- deployment scripts and smoke helpers tied to the old backend
- Python package code for local model experiments
- README instructions for model download and service bootstrap

### Separate backend repository owns

- concrete model choice
- service bootstrap and lifecycle scripts
- environment setup
- local deployment docs
- model download layout and smoke tests

## User Experience

### Main menu

The menu should stop presenting `Glint` as a service manager.

Keep:

- translation entry points
- API status headline/detail
- `Refresh Status`
- `API Settings...`
- shortcut panel entry

Remove:

- `Start Service`
- `Stop Service`
- `Restart Service`

Status wording should shift from `Service Status` to `API Status`, reflecting
that the app only knows whether a configured API endpoint is reachable.

### API settings panel

Introduce an `API Settings...` utility panel for runtime configuration.

Fields:

- `Base URL` text input
- `API Key` text input
- `Model` editable combo box
- `Refresh Models` button
- `Save` / `Cancel`

Behavior:

- load saved values when opened
- allow `model` to be typed manually even if model discovery fails
- keep current typed model when refreshing discovered models
- persist all three fields to `UserDefaults`
- apply changes immediately to translation and status checking

### Unconfigured state

If required API settings are missing, translation actions should fail with a
clear user-facing configuration error rather than silently assuming the old
local backend defaults.

## Architecture

### Configuration storage

Replace the hard-coded `AppConfig.default` deployment assumptions with a small
storage-backed configuration layer:

- `APISettings`
  - holds `baseURL`, `apiKey`, `model`
- `APISettingsStore`
  - loads and saves values from `UserDefaults`
- `AppConfig`
  - built from stored settings plus non-user-editable timing defaults

This keeps network code simple while removing repository-owned secrets or
deployment defaults.

### Translation client

Keep the current `/v1/chat/completions` client shape, but source request
parameters entirely from the persisted runtime settings. The client should not
know or care which backend repository is serving the request.

### Model discovery

Add a dedicated model discovery client for `GET /v1/models`.

Responsibilities:

- call the configured endpoint
- send auth headers consistent with the translation client
- decode model ids into a sorted list of model names
- surface errors without blocking manual model entry

### Status monitoring

Collapse backend status to API reachability only.

The monitor should:

- probe `GET /v1/models`
- report `available`, `unavailable`, or `error`
- stop trying to infer local process state

This keeps status honest and backend-agnostic.

## Data Flow

1. App launch loads persisted API settings from `UserDefaults`.
2. `AppConfig` is built from those settings plus timing constants.
3. Menu status refresh uses the current config to probe API reachability.
4. Translation workflows use the current config for chat completion requests.
5. API settings panel edits values in memory, refreshes models on demand, then
   saves to `UserDefaults`.
6. After save, `AppDelegate` refreshes status and future translation calls use
   the new settings immediately.

## Testing Strategy

Add or update tests for:

- persisted API settings round-trip
- model discovery success and failure fallback
- translation requests using current saved `baseURL`, `apiKey`, and `model`
- menu contract after service actions are removed
- API status refresh behavior with configured and unconfigured states

Remove or replace tests that depend on:

- backend control scripts
- local process detection
- old service menu actions

## Documentation Strategy

README and `README.en.md` should:

- position `Glint` as a macOS API client
- explain that users configure a compatible backend endpoint
- mention the author's current backend repository:
  `https://github.com/ZhengRui-Chen/HY-MT`
- remove embedded deployment instructions from this repository

## Acceptance Criteria

- no repository code depends on `oMLX` process lifecycle
- app menu exposes API configuration instead of service control
- `model` supports both manual entry and discovered choices
- API settings persist through app restarts using `UserDefaults`
- README points backend deployment users to the new backend repository
- Python deployment package and scripts are removed from this repository
