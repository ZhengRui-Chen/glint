# Backend Runtime Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add runtime-editable backend settings with immediate save-and-apply behavior, move backend controls into a dedicated popup panel, and switch backend status refresh to explicit on-demand checks.

**Architecture:** Introduce a persisted `BackendSettings` model and a rebuildable runtime assembly layer so translation clients and backend monitors can be replaced after settings changes. Keep the existing native menu for translation actions, but replace the old backend menu section with one `Backend...` entry that opens a custom panel reusing the shortcut panel's presentation style.

**Tech Stack:** Swift, SwiftUI, AppKit, UserDefaults, XCTest

---

### Task 1: Add a persisted backend settings model

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Config/BackendSettings.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/BackendSettingsTests.swift`

**Step 1: Write the failing settings persistence tests**

Cover:
- load falls back to defaults
- save and reload round-trips fields
- modes preserve their values
- reset/default helpers return expected values

**Step 2: Run the new test target and verify it fails**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendSettingsTests
```

Expected: test target fails because `BackendSettings` does not exist yet.

**Step 3: Implement `BackendMode` and `BackendSettings`**

Include:
- `managedLocal` / `externalAPI`
- `baseURL`
- `model`
- `apiKey`
- `load`
- `save`
- defaults

**Step 4: Run the same test target again**

Expected: `BackendSettingsTests` passes.

### Task 2: Introduce rebuildable backend runtime dependencies

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendRuntime.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendHealthChecker.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Networking/LocalTranslationClient.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendRuntimeTests.swift`

**Step 1: Write failing runtime replacement tests**

Cover:
- saving settings rebuilds the active translation client config
- external mode disables local control service actions
- app no longer depends on startup-only hard-coded backend config

**Step 2: Run the targeted test**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/AppDelegateBackendRuntimeTests
```

Expected: failures because runtime replacement is not wired yet.

**Step 3: Implement runtime assembly**

The runtime layer should:
- map `BackendSettings` into `AppConfig`
- create a `LocalTranslationClient`
- create a mode-aware backend status monitor
- provide optional backend control service support only for `managedLocal`

**Step 4: Update `AppDelegate` to use mutable runtime state**

Replace startup-frozen dependencies with current runtime lookups.

**Step 5: Re-run the targeted tests**

Expected: `AppDelegateBackendRuntimeTests` passes.

### Task 3: Replace periodic refresh with explicit backend checks

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusMonitor.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/BackendStatusMonitorTests.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`

**Step 1: Write failing tests for on-demand refresh behavior**

Cover:
- no repeating timer starts on launch
- save, check, start, stop, and restart trigger explicit refresh
- translation actions do not trigger separate preflight checks
- external API mode does not rely on local process checks

**Step 2: Run the targeted tests**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendStatusMonitorTests \
  -only-testing:GlintTests/AppDelegateBackendMenuTests
```

Expected: failures because the app still uses periodic refresh behavior.

**Step 3: Remove periodic refresh scheduling**

Refactor:
- delete or bypass timer-based refresh scheduling
- introduce `notChecked` as needed
- make refresh calls explicit and action-driven

**Step 4: Re-run the targeted tests**

Expected: on-demand refresh behavior passes.

### Task 4: Add the backend popup panel and menu entry

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelView.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelController.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/BackendPanelViewModelTests.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`

**Step 1: Write failing panel state tests**

Cover:
- draft state mirrors saved settings on open
- change detection works
- reset only affects draft state until save
- managed local shows local control actions
- external API hides local control actions

**Step 2: Run the targeted tests**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendPanelViewModelTests
```

Expected: failures because backend panel types do not exist yet.

**Step 3: Implement the panel using the shortcut panel style**

Match:
- floating panel behavior
- width and spacing conventions
- header and status block patterns

**Step 4: Replace the native backend menu cluster with `Backend...`**

Keep translation actions and shortcuts in the native menu.

**Step 5: Re-run the panel and menu tests**

Expected: backend panel tests pass and menu tests reflect the new entry point.

### Task 5: Wire save, check, and local controls into the backend panel

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelController.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/BackendPanelViewModelTests.swift`
- Test: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`

**Step 1: Write failing interaction tests**

Cover:
- `Done` with no changes closes only
- `Done` with changes saves, rebuilds runtime, refreshes status, closes
- `Check Backend` uses persisted settings only
- `Start`, `Stop`, `Restart` are available only in `managedLocal`

**Step 2: Run the targeted tests**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendPanelViewModelTests \
  -only-testing:GlintTests/AppDelegateBackendMenuTests
```

Expected: failures because action wiring is incomplete.

**Step 3: Implement panel actions**

Wire:
- save-and-apply on changed `Done`
- explicit `Check Backend`
- mode-gated local controls
- menu summary refresh after state changes

**Step 4: Re-run the targeted tests**

Expected: interaction tests pass.

### Task 6: Add remote API validation path without storing secrets

**Files:**
- Modify: `README.md` only if implementation needs developer notes
- Verify: no tracked file contains real secrets

**Step 1: Add local-only manual validation instructions outside git history**

Use env vars only:
- `SILICONFLOW_BASE_URL`
- `SILICONFLOW_API_KEY`
- `SILICONFLOW_MODEL`

**Step 2: Run repository verification**

Run:

```bash
uv run pytest
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint
git diff --check
```

Expected:
- Python tests pass
- Glint test suite passes
- no diff formatting issues

**Step 3: Run manual remote validation with env vars**

Use the SiliconFlow values from the user locally, exported in the shell only.
Do not commit, print into tracked files, or persist them in project config.

**Step 4: Verify no secrets are tracked**

Run:

```bash
git diff --cached
git diff
rg -n "sk-[A-Za-z0-9]" .
```

Expected: no real credentials in tracked changes.
