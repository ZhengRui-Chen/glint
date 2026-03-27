# App i18n String Catalog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Localize the macOS Glint app UI into English, Simplified Chinese, and Traditional Chinese using Apple's String Catalog workflow without adding an in-app language selector.

**Architecture:** Add a `Localizable.xcstrings` resource to the app target, route non-SwiftUI strings through a small localization helper, and migrate user-visible UI/workflow strings from hard-coded literals to Apple-native localization APIs. Keep tests centered on observable English output while sourcing those values from the localized access layer.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Xcode project resources, String Catalog (`.xcstrings`), XCTest

---

### Task 1: Add localization coverage tests

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/TextInputSourceWorkflowTests.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/LocalizationTests.swift`

**Step 1: Write the failing test**

Add assertions that:
- menu labels and permission labels come from localized accessors
- backend status headlines are localized
- workflow default error messages come from localized accessors

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/LocalizationTests -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/TextInputSourceWorkflowTests`

Expected: FAIL because localized accessors and catalog resources do not exist yet.

**Step 3: Write minimal implementation**

Create the smallest helper surface needed for tests to compile after Task 2 starts.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command and confirm those tests pass.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift \
  mac-app/HYMTQuickTranslate/GlintTests/TextInputSourceWorkflowTests.swift \
  mac-app/HYMTQuickTranslate/GlintTests/LocalizationTests.swift
git commit -m "test: add localization coverage"
```

### Task 2: Add the String Catalog and localization helper

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Localization/L10n.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/Localization/Localizable.xcstrings`
- Modify: `mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

Use the tests from Task 1 to drive the helper and resource wiring.

**Step 2: Run test to verify it fails**

Run the same targeted `xcodebuild test` command.

Expected: FAIL due to missing `L10n` and missing resource wiring.

**Step 3: Write minimal implementation**

Add:
- a small `L10n` namespace for non-SwiftUI strings
- one `Localizable.xcstrings` catalog with `en`, `zh-Hans`, and `zh-Hant` entries
- project file resource references so the app target bundles the catalog

**Step 4: Run test to verify it passes**

Run the targeted `xcodebuild test` command again.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Localization/L10n.swift \
  mac-app/HYMTQuickTranslate/Glint/Localization/Localizable.xcstrings \
  mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj
git commit -m "feat: add string catalog infrastructure"
```

### Task 3: Migrate menu, backend, workflow, and panel strings

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Workflow/TranslateClipboardWorkflow.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/OCR/OCRImageInputSource.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Hotkey/ShortcutPanelView.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/OCR/ScreenRegionSelectionView.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/UI/OverlayContentView.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/GlintApp.swift`

**Step 1: Write the failing test**

Extend existing menu and workflow tests so they fail against any remaining hard-coded strings that bypass the localization helper.

**Step 2: Run test to verify it fails**

Run:
`xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/AppDelegateBackendMenuTests -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/TextInputSourceWorkflowTests`

Expected: FAIL until the migrated code reads from localized resources.

**Step 3: Write minimal implementation**

Replace hard-coded user-visible strings with:
- `Text("...")` or localized string resources in SwiftUI
- `L10n` accessors backed by `String(localized:)` for non-SwiftUI logic

**Step 4: Run test to verify it passes**

Run the targeted `xcodebuild test` command again.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift \
  mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift \
  mac-app/HYMTQuickTranslate/Glint/Workflow/TranslateClipboardWorkflow.swift \
  mac-app/HYMTQuickTranslate/Glint/OCR/OCRImageInputSource.swift \
  mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift \
  mac-app/HYMTQuickTranslate/Glint/Hotkey/ShortcutPanelView.swift \
  mac-app/HYMTQuickTranslate/Glint/OCR/ScreenRegionSelectionView.swift \
  mac-app/HYMTQuickTranslate/Glint/UI/OverlayContentView.swift \
  mac-app/HYMTQuickTranslate/Glint/App/GlintApp.swift
git commit -m "feat: localize app ui strings"
```

### Task 4: Full verification

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/AppDelegateBackendMenuTests.swift`
- Modify: any remaining tests touched by localization surface changes

**Step 1: Write the failing test**

Adjust any remaining brittle assertions that directly hard-code strings now sourced through `L10n`.

**Step 2: Run test to verify it fails**

Run the full suite:
`xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: Any failing assertions should point to missed localized access paths.

**Step 3: Write minimal implementation**

Fix the remaining tests or missed string migrations without broad refactors.

**Step 4: Run test to verify it passes**

Run the full suite again and confirm success.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/GlintTests
git commit -m "test: align suite with localized strings"
```
