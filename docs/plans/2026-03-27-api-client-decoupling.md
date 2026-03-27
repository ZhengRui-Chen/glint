# API Client Decoupling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn `Glint` into a pure OpenAI-compatible API client, add editable runtime API settings for `baseURL`, `apiKey`, and `model`, and remove backend/model deployment responsibilities from this repository.

**Architecture:** Replace deployment-specific defaults with a `UserDefaults`-backed API settings store, add a model discovery client for `/v1/models`, reframe status checking around API reachability only, and remove local backend control paths from the app and repository docs.

**Tech Stack:** Swift, AppKit, SwiftUI, Foundation networking, UserDefaults, XCTest, xcodebuild

---

### Task 1: Lock the new app configuration surface with failing tests

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/GlintTests.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/APISettingsStoreTests.swift`

**Step 1: Write the failing test**

Add tests that assert:

- default app config no longer hard-codes `HY-MT` deployment values
- API settings can round-trip through a dedicated store
- empty persisted settings are handled without inventing backend defaults

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/GlintTests -only-testing:GlintTests/APISettingsStoreTests
```

Expected: FAIL because the settings store does not exist and app config still
contains old deployment defaults.

**Step 3: Write minimal implementation**

Create the smallest storage-backed API settings types needed for those tests:

- `APISettings`
- `APISettingsStore`
- updated `AppConfig`

**Step 4: Run test to verify it passes**

Run the same command and confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Config/AppConfig.swift mac-app/HYMTQuickTranslate/Glint/Config/APISettings.swift mac-app/HYMTQuickTranslate/GlintTests/GlintTests.swift mac-app/HYMTQuickTranslate/GlintTests/APISettingsStoreTests.swift
git commit -m "feat: persist runtime api settings"
```

### Task 2: Add model discovery with test-first coverage

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Networking/ModelDiscoveryClient.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/ModelDiscoveryClientTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Networking/ChatCompletionModels.swift`

**Step 1: Write the failing test**

Add tests that assert:

- `/v1/models` responses decode into model ids
- results are sorted for display
- non-2xx responses surface an error
- missing model list data does not fake entries

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/ModelDiscoveryClientTests
```

Expected: FAIL because the discovery client and response model do not exist yet.

**Step 3: Write minimal implementation**

Implement:

- lightweight response models for `/v1/models`
- `ModelDiscoveryClient`
- shared request auth/header wiring where needed

**Step 4: Run test to verify it passes**

Run the same command and confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Networking/ModelDiscoveryClient.swift mac-app/HYMTQuickTranslate/Glint/Networking/ChatCompletionModels.swift mac-app/HYMTQuickTranslate/GlintTests/ModelDiscoveryClientTests.swift
git commit -m "feat: add api model discovery"
```

### Task 3: Reframe translation and status around runtime API settings

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/Networking/LocalTranslationClient.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendHealthChecker.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusMonitor.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Localization/L10n.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Localization/Localizable.xcstrings`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/BackendStatusMonitorTests.swift`

**Step 1: Write the failing test**

Add tests that assert:

- translation requests use the current stored `baseURL`, `apiKey`, and `model`
- status checks no longer depend on local process probing
- missing configuration yields a clear status/error path

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendStatusMonitorTests -only-testing:GlintTests/LocalTranslationClientTests
```

Expected: FAIL because the app still uses deployment defaults and process-based
status semantics.

**Step 3: Write minimal implementation**

Update translation and status code to:

- build requests from runtime settings
- treat `/v1/models` reachability as the status source
- remove process-based branches
- localize API-oriented status text

**Step 4: Run test to verify it passes**

Run the same command and confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Networking/LocalTranslationClient.swift mac-app/HYMTQuickTranslate/Glint/Backend/BackendHealthChecker.swift mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusMonitor.swift mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift mac-app/HYMTQuickTranslate/Glint/Localization/L10n.swift mac-app/HYMTQuickTranslate/Glint/Localization/Localizable.xcstrings mac-app/HYMTQuickTranslate/GlintTests/BackendStatusMonitorTests.swift mac-app/HYMTQuickTranslate/GlintTests/LocalTranslationClientTests.swift
git commit -m "feat: use runtime api config for status and translation"
```

### Task 4: Replace service controls with API settings UI

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/APISettings/APISettingsPanelController.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/APISettings/APISettingsView.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/APISettings/APISettingsViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/APISettingsViewModelTests.swift`

**Step 1: Write the failing test**

Add tests that assert:

- the menu exposes `API Settings...`
- start/stop/restart actions are gone
- the settings view model loads current settings, refreshes model options, and
  allows manual model entry

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/AppDelegateBackendMenuTests -only-testing:GlintTests/APISettingsViewModelTests
```

Expected: FAIL because the current menu still exposes service actions and no API
settings panel exists.

**Step 3: Write minimal implementation**

Implement the settings panel and wire it into `AppDelegate`:

- open panel from menu
- load saved settings
- refresh model list on demand
- save settings to `UserDefaults`
- refresh live menu status after save

**Step 4: Run test to verify it passes**

Run the same command and confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/APISettings mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift mac-app/HYMTQuickTranslate/GlintTests/APISettingsViewModelTests.swift
git commit -m "feat: add api settings panel"
```

### Task 5: Remove repository-owned backend deployment code

**Files:**
- Delete: `src/hy_mt_deploy/`
- Delete: `tests/test_translate_gemma.py`
- Delete: deployment-specific files in `scripts/`
- Modify: `pyproject.toml`
- Modify: `README.md`
- Modify: `README.en.md`

**Step 1: Write the failing test**

Add or update documentation-facing assertions where practical, then rely on
repository verification for the removal itself:

- Python test suite should no longer depend on removed package files
- README should point backend setup to `https://github.com/ZhengRui-Chen/HY-MT`

**Step 2: Run verification to confirm the old repository shape still exists**

Run:

```bash
rg -n "oMLX|HY-MT1.5-1.8B-4bit|start_omlx|stop_omlx|restart_omlx|hy_mt_deploy" README.md README.en.md pyproject.toml src tests scripts mac-app/HYMTQuickTranslate
```

Expected: existing deployment-specific references are still present.

**Step 3: Write minimal implementation**

Remove deployment code and rewrite docs so `Glint` is described as a client that
can be used with the separate backend repository.

**Step 4: Run verification to confirm removal**

Run:

```bash
rg -n "oMLX|HY-MT1.5-1.8B-4bit|start_omlx|stop_omlx|restart_omlx|hy_mt_deploy" README.md README.en.md pyproject.toml src tests scripts mac-app/HYMTQuickTranslate
```

Expected: only intentional references remain, including the link to the new
backend repository.

**Step 5: Commit**

```bash
git add README.md README.en.md pyproject.toml src tests scripts
git commit -m "refactor: remove embedded backend deployment"
```

### Task 6: Run full verification

**Files:**
- Verify: `mac-app/HYMTQuickTranslate/Glint`
- Verify: `mac-app/HYMTQuickTranslate/GlintTests`
- Verify: `README.md`
- Verify: `README.en.md`

**Step 1: Run the full macOS test suite**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'
```

Expected: PASS.

**Step 2: Run the Python test suite or equivalent cleanup verification**

Run:

```bash
uv run pytest -q
```

Expected: PASS if Python tests remain, or an intentionally empty test surface if
the old package is fully removed.

**Step 3: Build the app**

Run:

```bash
zsh scripts/build_mac_app.sh
```

Expected: PASS, unless the build helper was intentionally removed as part of the
repo cleanup. If removed, run the equivalent `xcodebuild build` command.

**Step 4: Perform a final repository scan**

Run:

```bash
git status --short
rg -n "omlx serve --model-dir|HY-MT1.5-1.8B-4bit|local-hy-key" .
```

Expected: only intended changes remain and no stale deployment-specific literals
survive in app code.
