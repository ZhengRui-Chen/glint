# Backend API-Only Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove backend mode and local service lifecycle management from Glint so the app behaves as a pure API client with runtime-editable backend settings.

**Architecture:** Keep the backend popup panel and runtime rebuild path, but collapse backend settings to API fields only and delete all local-service control branches. Preserve old saved settings with a compatibility decoder that ignores the legacy mode field while keeping API values intact.

**Tech Stack:** Swift, SwiftUI, AppKit, UserDefaults, XCTest

---

### Task 1: Add failing tests for API-only settings and legacy migration

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/BackendSettingsTests.swift`

**Step 1: Write the failing tests**

Cover:
- current `BackendSettings` has no mode in public behavior
- legacy saved payload with `mode` still loads and preserves `baseURL`, `model`,
  and `apiKey`
- defaults still load correctly

**Step 2: Run the targeted test**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendSettingsTests
```

Expected: FAIL because current settings model still depends on `mode`.

### Task 2: Remove mode and local-control branches from the panel and menu tests

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/BackendPanelViewModelTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`

**Step 1: Write failing tests**

Cover:
- backend panel no longer exposes managed-local controls
- `Done` with changed API settings still saves, rebuilds runtime, and checks once
- native menu exposes `Backend...` only, without start/stop/restart actions

**Step 2: Run the targeted tests**

Run:

```bash
xcodebuild test \
  -project mac-app/HYMTQuickTranslate/Glint.xcodeproj \
  -scheme Glint \
  -only-testing:GlintTests/BackendPanelViewModelTests \
  -only-testing:GlintTests/AppDelegateBackendMenuTests \
  -only-testing:GlintTests/MenuBarViewModelTests
```

Expected: FAIL because current implementation still contains mode and lifecycle
control assumptions.

### Task 3: Simplify runtime and UI implementation

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/Config/BackendSettings.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendRuntime.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelView.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendPanelController.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Localization/L10n.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Localization/Localizable.xcstrings`

**Step 1: Implement minimal production changes**

Make these changes only:
- remove `BackendMode`
- add legacy decoding support for old saved settings
- remove control-service wiring from runtime
- remove start/stop/restart handling from app delegate, panel, and menu view
  model
- keep save/check/reset/done behavior intact
- keep API-only status checking intact

**Step 2: Re-run targeted tests**

Expected: PASS for all targeted API-only behavior tests.

### Task 4: Run full verification and remote API validation

**Files:**
- Verify only

**Step 1: Run automated verification**

Run:

```bash
xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint
uv run pytest
git diff --check
```

Expected:
- Xcode tests pass
- Python tests pass
- no diff formatting issues

**Step 2: Run remote API validation**

Use local environment variables only:
- `SILICONFLOW_BASE_URL`
- `SILICONFLOW_API_KEY`
- `SILICONFLOW_MODEL`

Verify:
- `GET /v1/models`
- `POST /v1/chat/completions`

**Step 3: Commit**

```bash
git add <updated files>
git commit -m "refactor: make backend settings api-only"
```
