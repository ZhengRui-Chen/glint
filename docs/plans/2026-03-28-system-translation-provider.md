# System Translation Provider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a provider switch in `API Settings` so Glint can translate through either `Custom API` or macOS `System Translation` without requiring an HTTP endpoint in system mode.

**Architecture:** Persist a `TranslationProvider`, split the settings panel into provider tabs, route translation requests through a runtime provider-aware client, and make backend status provider-aware so system translation keeps menu actions enabled.

**Tech Stack:** Swift 6, AppKit, SwiftUI, Xcode unit tests, macOS Translation framework

---

### Task 1: Add provider-aware settings coverage

**Files:**
- Modify: `mac-app/GlintTests/APISettingsStoreTests.swift`
- Modify: `mac-app/GlintTests/APISettingsPanelControllerTests.swift`

**Step 1: Write failing store tests**

Add tests for:

- saving/loading a `system` provider
- loading legacy saved JSON without provider and defaulting to `customAPI`

**Step 2: Run the targeted tests**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/APISettingsStoreTests -only-testing:GlintTests/APISettingsPanelControllerTests`
Expected: FAIL because provider does not exist yet

**Step 3: Implement provider persistence and panel draft state**

Add `TranslationProvider`, store it in `APISettings`, and update panel state/controller behavior.

**Step 4: Re-run the targeted tests**

Run the same command and expect those tests to pass.

### Task 2: Add provider-aware backend status coverage

**Files:**
- Modify: `mac-app/GlintTests/BackendStatusMonitorTests.swift`
- Modify: `mac-app/GlintTests/MenuBarViewModelTests.swift`

**Step 1: Write failing status tests**

Add tests proving:

- system provider returns a dedicated system status without calling HTTP checker
- system status keeps translation enabled and disables refresh

**Step 2: Run the targeted tests**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendStatusMonitorTests -only-testing:GlintTests/MenuBarViewModelTests`
Expected: FAIL because system status does not exist yet

**Step 3: Implement provider-aware status snapshots**

Update `BackendStatusSnapshot`, `BackendStatusMonitor`, and any dependent strings.

**Step 4: Re-run the targeted tests**

Run the same command and expect those tests to pass.

### Task 3: Add provider-aware translation routing coverage

**Files:**
- Create: `mac-app/GlintTests/RuntimeTranslationClientTests.swift`
- Modify: `mac-app/GlintTests/LocalTranslationClientTests.swift`

**Step 1: Write failing routing tests**

Add tests proving:

- `customAPI` uses the HTTP client
- `system` uses the system translation client

**Step 2: Run the targeted tests**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/RuntimeTranslationClientTests -only-testing:GlintTests/LocalTranslationClientTests`
Expected: FAIL because the runtime router does not exist yet

**Step 3: Implement runtime routing and system translation client**

Introduce a provider-aware default client and wire workflows to use it.

**Step 4: Re-run the targeted tests**

Run the same command and expect those tests to pass.

### Task 4: Update settings UI and localization

**Files:**
- Modify: `mac-app/Glint/APISettings/APISettingsPanelController.swift`
- Modify: `mac-app/Glint/Localization/L10n.swift`
- Modify: `mac-app/Glint/Localization/Localizable.xcstrings`

**Step 1: Write or extend failing panel tests**

Cover:

- provider tab labels
- system page save behavior
- system page model refresh no-op

**Step 2: Run panel-related tests**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/APISettingsPanelControllerTests`
Expected: FAIL until UI state and labels are updated

**Step 3: Implement the segmented provider UI**

Show `Custom API` and `System Translation` tabs, conditionally render page content, and update copy.

**Step 4: Re-run panel-related tests**

Run the same command and expect them to pass.

### Task 5: Full verification

**Files:**
- Verify: `mac-app/Glint`
- Verify: `mac-app/GlintTests`
- Verify: `docs/plans/2026-03-28-system-translation-provider-design.md`
- Verify: `docs/plans/2026-03-28-system-translation-provider.md`

**Step 1: Run the full macOS test suite**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
Expected: PASS

**Step 2: Review the final diff surface**

Run: `git status --short && git diff --stat`
Expected: only provider, settings UI, translation routing, status, localization, and test changes
