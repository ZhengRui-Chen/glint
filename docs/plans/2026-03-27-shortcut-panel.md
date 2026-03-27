# Shortcut Panel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the inline menu-based shortcut recorder with a dedicated Glint shortcut panel that supports recording, validation, reset-to-defaults, and immediate hotkey reload.

**Architecture:** Keep the current hotkey model and registration pipeline intact. Introduce a small utility panel plus a panel-specific view model, replace the menu's inline recorder items with a single `Keyboard Shortcuts…` entry, and drive all shortcut edits through the panel so recording and feedback are centralized.

**Tech Stack:** AppKit, SwiftUI hosting where already used by the app, existing `ShortcutRecorder` and `GlobalHotkeyMonitor`, XCTest

---

### Task 1: Lock menu behavior with failing tests

**Files:**
- Modify: `mac-app/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/GlintTests/AppDelegateBackendMenuTests.swift`

**Step 1: Write failing tests for the new menu contract**

Add assertions that the menu:

- includes `Keyboard Shortcuts…`
- no longer includes inline shortcut recorder items
- no longer includes inline cancel-recording menu items

**Step 2: Run targeted tests to verify they fail**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/AppDelegateBackendMenuTests
```

Expected: FAIL because the current menu still exposes inline recorder items.

**Step 3: Commit nothing yet**

Do not commit until the panel wiring and menu rewrite pass together.

### Task 2: Introduce panel state model with TDD

**Files:**
- Create: `mac-app/Glint/Hotkey/ShortcutPanelViewModel.swift`
- Create: `mac-app/GlintTests/ShortcutPanelViewModelTests.swift`

**Step 1: Write failing tests for panel state**

Cover:

- idle state shows current selection and clipboard shortcuts
- starting a recording marks only one target active
- duplicate shortcuts surface a hard error message
- successful save updates the visible shortcut and feedback message
- reset restores both defaults and emits the right feedback

**Step 2: Run targeted tests to verify they fail**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/ShortcutPanelViewModelTests
```

Expected: FAIL because the new panel model does not exist yet.

**Step 3: Write the minimal implementation**

Implement a panel-focused view model that owns:

- current shortcuts
- active recording target
- current status message
- commands for start recording, cancel, apply recorded shortcut, and reset

Reuse `ShortcutRecorder` validation rather than duplicating shortcut rules.

**Step 4: Run targeted tests to verify they pass**

Run the same command again and confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/Glint/Hotkey/ShortcutPanelViewModel.swift mac-app/GlintTests/ShortcutPanelViewModelTests.swift
git commit -m "feat: add shortcut panel state model"
```

### Task 3: Build the shortcut panel UI shell

**Files:**
- Create: `mac-app/Glint/Hotkey/ShortcutPanelController.swift`
- Create: `mac-app/Glint/Hotkey/ShortcutPanelView.swift`
- Create: `mac-app/Glint/Hotkey/ShortcutRecorderButton.swift`
- Test: `mac-app/GlintTests/ShortcutPanelViewModelTests.swift`

**Step 1: Write one failing behavior test for panel actions if needed**

If there is no existing UI-free seam yet, add or extend tests so the panel
controller can be driven without manual interaction.

**Step 2: Implement the utility panel shell**

Create a compact utility panel that includes:

- title and description
- two recorder rows
- status message area
- `Reset to Defaults`
- `Done`

**Step 3: Reuse Glint motion language**

Apply restrained transitions consistent with the existing overlay:

- open fade + upward drift
- close fade + downward drift
- active recorder highlight transition
- status message fade transition

**Step 4: Verify the panel builds cleanly**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/ShortcutPanelViewModelTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add mac-app/Glint/Hotkey/ShortcutPanelController.swift mac-app/Glint/Hotkey/ShortcutPanelView.swift mac-app/Glint/Hotkey/ShortcutRecorderButton.swift mac-app/GlintTests/ShortcutPanelViewModelTests.swift
git commit -m "feat: add shortcut panel ui"
```

### Task 4: Rewire AppDelegate and menu entry

**Files:**
- Modify: `mac-app/Glint/App/AppDelegate.swift`
- Modify: `mac-app/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/GlintTests/AppDelegateBackendMenuTests.swift`

**Step 1: Replace inline recorder menu items**

Remove menu-driven recording labels and replace them with:

- `Keyboard Shortcuts…`

**Step 2: Add AppDelegate wiring**

AppDelegate should:

- lazily own the new shortcut panel controller
- open the panel from the menu action
- synchronize current shortcut settings into the panel
- apply panel saves back into active hotkey registrations

**Step 3: Remove obsolete inline recording state exposure from the menu**

Delete menu-only recording affordances that are no longer part of the product
flow.

**Step 4: Run targeted menu tests**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests -only-testing:GlintTests/AppDelegateBackendMenuTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add mac-app/Glint/App/AppDelegate.swift mac-app/Glint/MenuBar/MenuBarViewModel.swift mac-app/Glint/MenuBar/StatusBarController.swift mac-app/GlintTests/MenuBarViewModelTests.swift mac-app/GlintTests/AppDelegateBackendMenuTests.swift
git commit -m "feat: replace inline shortcut menu with panel"
```

### Task 5: Finish shortcut application and reset behavior

**Files:**
- Modify: `mac-app/Glint/Hotkey/ShortcutRecorder.swift`
- Modify: `mac-app/Glint/Config/ShortcutSettings.swift`
- Modify: `mac-app/GlintTests/ShortcutRecorderTests.swift`
- Modify: `mac-app/GlintTests/ShortcutPanelViewModelTests.swift`

**Step 1: Add failing tests for reset and panel-driven apply**

Cover:

- reset restores both default shortcuts
- applying a shortcut from the panel immediately updates live hotkey settings
- duplicate shortcuts still fail cleanly

**Step 2: Run targeted tests to verify they fail**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/ShortcutRecorderTests -only-testing:GlintTests/ShortcutPanelViewModelTests
```

Expected: FAIL until the new reset/apply flow is implemented.

**Step 3: Implement minimal support code**

Only add helpers that the panel flow actually needs, such as:

- restoring default settings
- emitting panel-friendly success/error outcomes

Do not broaden the shortcut model beyond this workflow.

**Step 4: Re-run targeted tests**

Confirm PASS.

**Step 5: Commit**

```bash
git add mac-app/Glint/Hotkey/ShortcutRecorder.swift mac-app/Glint/Config/ShortcutSettings.swift mac-app/GlintTests/ShortcutRecorderTests.swift mac-app/GlintTests/ShortcutPanelViewModelTests.swift
git commit -m "feat: support shortcut panel apply and reset"
```

### Task 6: Full verification and polish

**Files:**
- Verify: `mac-app/Glint/App/AppDelegate.swift`
- Verify: `mac-app/Glint/MenuBar/MenuBarViewModel.swift`
- Verify: `mac-app/Glint/MenuBar/StatusBarController.swift`
- Verify: `mac-app/Glint/Hotkey/ShortcutPanelController.swift`
- Verify: `mac-app/Glint/Hotkey/ShortcutPanelView.swift`
- Verify: `mac-app/Glint/Hotkey/ShortcutRecorderButton.swift`

**Step 1: Run the full macOS test suite**

Run:

```bash
xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'
```

Expected: all tests pass.

**Step 2: Build the app**

Run:

```bash
zsh scripts/build_mac_app.sh
```

Expected: `BUILD SUCCEEDED`

**Step 3: Perform a manual spot check**

Verify manually that:

- the menu now shows `Keyboard Shortcuts…`
- the panel opens with the right two shortcuts
- recording works for both actions
- `Esc` cancels
- reset restores defaults
- motion feels aligned with the existing overlay

**Step 4: Commit**

```bash
git add mac-app/Glint mac-app/GlintTests
git commit -m "feat: polish shortcut panel flow"
```
