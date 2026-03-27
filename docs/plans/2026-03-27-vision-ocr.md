# Vision OCR Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a third input mode that lets the user select a screen region, extract text with Apple Vision OCR, and translate it through the existing Glint overlay.

**Architecture:** Keep translation logic centralized in `TranslateTextWorkflow`, add a dedicated OCR input source plus a region-selection controller, and thread the new OCR action through menu and shortcut wiring. Reuse current overlay visuals and animation timing so OCR feels native to Glint instead of bolted on.

**Tech Stack:** Swift, AppKit, SwiftUI, Vision, CoreGraphics, XCTest, xcodebuild

---

### Task 1: Document OCR surface in tests

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/ShortcutSettingsTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/ShortcutRecorderTests.swift`

**Step 1: Write the failing tests**

Add tests that assert:
- `MenuBarViewModel` exposes `Translate OCR Area`
- OCR callback is invoked
- default OCR shortcut is `Control + Option + Command + O`
- shortcut settings reject OCR duplicates
- `AppDelegate` registers and reloads an OCR hotkey monitor

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/ShortcutSettingsTests -only-testing:GlintTests/ShortcutRecorderTests`

Expected: FAIL because OCR labels, settings, and monitor wiring do not exist yet.

**Step 3: Write minimal implementation**

Update menu/shortcut models to include the OCR target and default shortcut, but do not add the capture UI yet.

**Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command and confirm those suites pass.

**Step 5: Commit**

```bash
git add docs/plans/2026-03-27-vision-ocr-design.md docs/plans/2026-03-27-vision-ocr.md mac-app/HYMTQuickTranslate/Glint mac-app/HYMTQuickTranslate/GlintTests
git commit -m "feat: add OCR menu and shortcut wiring"
```

### Task 2: Add OCR workflow seams and tests

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/OCR/VisionOCRService.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/OCR/OCRImageInputSource.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Workflow/TranslateClipboardWorkflow.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/OCRWorkflowTests.swift`

**Step 1: Write the failing test**

Add focused tests for:
- OCR service joins multiple recognized lines predictably
- OCR input source returns `.noText` when Vision finds nothing
- OCR workflow maps successful OCR into translation requests

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/OCRWorkflowTests`

Expected: FAIL because OCR service and input source do not exist.

**Step 3: Write minimal implementation**

Create protocol-based OCR service and OCR-backed `TextInputSource`, then expose an OCR workflow that reuses `TranslateTextWorkflow`.

**Step 4: Run test to verify it passes**

Run the same targeted test command and confirm pass.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/OCR mac-app/HYMTQuickTranslate/Glint/Workflow/TranslateClipboardWorkflow.swift mac-app/HYMTQuickTranslate/GlintTests/OCRWorkflowTests.swift
git commit -m "feat: add Vision OCR workflow"
```

### Task 3: Add screen-region selection UI and app wiring

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/OCR/ScreenRegionSelectionController.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/OCR/ScreenRegionSelectionView.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

Extend existing tests to assert OCR menu items remain visible/enabled during backend refresh and OCR action wiring exists in the app delegate.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/AppDelegateBackendMenuTests -only-testing:GlintTests/ShortcutRecorderTests`

Expected: FAIL because the UI and app delegate do not yet expose OCR behavior end-to-end.

**Step 3: Write minimal implementation**

Add the region-selection controller and integrate it with `AppDelegate` so the OCR path becomes usable from the menu and hotkey.

**Step 4: Run test to verify it passes**

Run the same targeted test command and confirm pass.

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift mac-app/HYMTQuickTranslate/Glint/OCR mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj mac-app/HYMTQuickTranslate/GlintTests
git commit -m "feat: add OCR capture selection UI"
```

### Task 4: Full verification

**Files:**
- Verify: `mac-app/HYMTQuickTranslate/Glint`
- Verify: `mac-app/HYMTQuickTranslate/GlintTests`
- Verify: `mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj`

**Step 1: Run full test suite**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: PASS with 0 failures.

**Step 2: Run build verification**

Run: `xcodebuild build -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: BUILD SUCCEEDED.

**Step 3: Inspect worktree diff**

Run: `git status --short && git diff --stat`

Expected: Only OCR-related files and docs changed.

**Step 4: Commit**

```bash
git add docs/plans/2026-03-27-vision-ocr-design.md docs/plans/2026-03-27-vision-ocr.md mac-app/HYMTQuickTranslate/Glint mac-app/HYMTQuickTranslate/GlintTests mac-app/HYMTQuickTranslate/Glint.xcodeproj/project.pbxproj
git commit -m "feat: add experimental Vision OCR translation flow"
```
