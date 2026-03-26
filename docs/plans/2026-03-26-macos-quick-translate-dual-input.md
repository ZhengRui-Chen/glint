# macOS Quick Translate Dual Input Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a menu bar control surface plus a second translation path that translates currently selected text with its own configurable shortcut while preserving the existing clipboard path.

**Architecture:** Generalize the current clipboard-only workflow into input-source-driven translation, add a small menu bar layer for actions and shortcut configuration, and isolate selected-text capture behind an accessibility-based input source. Preserve the current overlay panel and reuse it for both input paths, with position preference determined by the trigger path.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, Accessibility APIs, UserDefaults, Xcode macOS app target

---

### Task 1: Add a persisted shortcut settings model

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Config/ShortcutSettings.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/ShortcutSettingsTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class ShortcutSettingsTests: XCTestCase {
    func test_settings_use_distinct_default_shortcuts() {
        let settings = ShortcutSettings.default
        XCTAssertNotEqual(settings.clipboardShortcut, settings.selectionShortcut)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/ShortcutSettingsTests`
Expected: FAIL because the settings type does not exist.

**Step 3: Write minimal implementation**

```swift
struct ShortcutSettings: Equatable {
    let clipboardShortcut: GlobalHotkeyShortcut
    let selectionShortcut: GlobalHotkeyShortcut

    static let `default` = ShortcutSettings(
        clipboardShortcut: .default,
        selectionShortcut: .selectionDefault
    )
}
```

Implement:

- defaults for clipboard and selection shortcuts
- local persistence with `UserDefaults`
- duplicate-shortcut rejection helper

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/ShortcutSettingsTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add shortcut settings model"
```

### Task 2: Generalize workflow input around text sources

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Input/TextInputSource.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Input/ClipboardInputSource.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Workflow/TranslateClipboardWorkflow.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/TextInputSourceWorkflowTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class TextInputSourceWorkflowTests: XCTestCase {
    func test_workflow_returns_error_when_input_source_has_no_text() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(.noText)),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )
        let state = await workflow.run()
        XCTAssertEqual(state, .error("No text was provided."))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/TextInputSourceWorkflowTests`
Expected: FAIL because the generalized workflow and input-source types do not exist.

**Step 3: Write minimal implementation**

```swift
protocol TextInputSource: Sendable {
    func resolveText() async -> Result<String, TextInputSourceError>
}

enum TextInputSourceError: Error, Equatable {
    case noText
}
```

Implement:

- a generalized translation workflow driven by `TextInputSource`
- clipboard input as a conforming source
- compatibility layer so existing clipboard behavior still works through the new workflow

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/TextInputSourceWorkflowTests -only-testing:HYMTQuickTranslateTests/TranslateClipboardWorkflowTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "refactor: generalize translation workflow inputs"
```

### Task 3: Add selected-text input source with accessibility-aware errors

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Input/SelectionInputSource.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Input/AccessibilityPermission.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/SelectionInputSourceTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class SelectionInputSourceTests: XCTestCase {
    func test_selection_input_reports_missing_permission() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: false),
            provider: StubSelectionProvider(result: .failure(.noText))
        )
        let result = await source.resolveText()
        XCTAssertEqual(result, .failure(.permissionRequired))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/SelectionInputSourceTests`
Expected: FAIL because selection input types do not exist.

**Step 3: Write minimal implementation**

```swift
enum TextInputSourceError: Error, Equatable {
    case noText
    case permissionRequired
    case unsupportedHostApp
}
```

Implement:

- accessibility permission checker
- selection input source that refuses to proceed when permission is missing
- explicit error mapping for no selection vs unsupported host-app behavior
- no silent fallback to clipboard

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/SelectionInputSourceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add accessibility-based selection input"
```

### Task 4: Add menu bar app state and actions

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/MenuBar/StatusBarController.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppDelegate.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/MenuBarViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class MenuBarViewModelTests: XCTestCase {
    func test_menu_bar_exposes_permission_status() {
        let viewModel = MenuBarViewModel(permissionStatus: .required)
        XCTAssertEqual(viewModel.permissionLabel, "Accessibility Permission: Required")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/MenuBarViewModelTests`
Expected: FAIL because the menu bar view model does not exist.

**Step 3: Write minimal implementation**

```swift
enum AccessibilityPermissionStatus: Equatable {
    case granted
    case required
}
```

Implement:

- a status bar item with menu entries for selection and clipboard actions
- permission state label
- wiring from `AppDelegate` so the app becomes a menu bar utility instead of only an accessory process

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/MenuBarViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add menu bar control surface"
```

### Task 5: Add shortcut recording and persistence for both paths

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Hotkey/ShortcutRecorder.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Hotkey/GlobalHotkeyMonitor.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/MenuBar/MenuBarViewModel.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/ShortcutRecorderTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class ShortcutRecorderTests: XCTestCase {
    func test_recorder_rejects_duplicate_shortcuts() {
        let settings = ShortcutSettings.default
        let recorder = ShortcutRecorder(existingSettings: settings)
        let result = recorder.validate(settings.clipboardShortcut, for: .selection)
        XCTAssertEqual(result, .failure(.duplicateShortcut))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/ShortcutRecorderTests`
Expected: FAIL because the recorder does not exist.

**Step 3: Write minimal implementation**

```swift
enum ShortcutRecorderError: Error, Equatable {
    case duplicateShortcut
}
```

Implement:

- lightweight shortcut-recording mode from the menu bar
- validation against duplicate assignments
- persistence back into `ShortcutSettings`
- monitor reload when shortcuts change

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/ShortcutRecorderTests -only-testing:HYMTQuickTranslateTests/ShortcutSettingsTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add configurable dual shortcuts"
```

### Task 6: Add selection-trigger path and cursor-near overlay placement

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayPlacementResolver.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayPanelController.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppDelegate.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/OverlayPlacementResolverTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class OverlayPlacementResolverTests: XCTestCase {
    func test_resolver_falls_back_to_center_when_cursor_anchor_is_unavailable() {
        let resolver = OverlayPlacementResolver()
        let placement = resolver.resolve(cursorAnchor: nil)
        XCTAssertEqual(placement, .centered)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlayPlacementResolverTests`
Expected: FAIL because the placement resolver does not exist.

**Step 3: Write minimal implementation**

```swift
enum OverlayPlacement: Equatable {
    case centered
    case anchored(CGPoint)
}
```

Implement:

- placement resolver for cursor-near vs centered positioning
- selection shortcut path in `AppDelegate`
- overlay presentation that uses anchored placement when available

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlayPlacementResolverTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add selection-triggered overlay placement"
```

### Task 7: Update docs and run full verification

**Files:**
- Modify: `README.md`

**Step 1: Write the failing verification checklist**

Checklist:

- menu bar is visible after launch
- clipboard and selection actions are both accessible
- two shortcuts can be configured and persisted
- selection path reports permission errors clearly
- selection path does not silently fall back to clipboard
- cursor-near placement falls back safely

**Step 2: Run current full verification**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS only after all earlier tasks are complete.

**Step 3: Write minimal documentation**

Add README sections for:

- menu bar usage
- clipboard vs selection triggers
- separate shortcut configuration
- accessibility permission requirement for selection translation
- supported and unsupported selection scenarios

**Step 4: Run final verification**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS

Run: `xcodebuild build -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

Run: `uv run python -m pytest -q`
Expected: PASS

Manual verification:

- launch app and confirm menu bar item appears
- trigger clipboard translation and confirm old path still works
- trigger selection translation without permission and confirm explicit error
- grant permission and retry selection translation in a supported app
- verify clipboard shortcut and selection shortcut are distinct and configurable
- verify unsupported host-app selection path reports error rather than using clipboard

**Step 5: Commit**

```bash
git add README.md mac-app/HYMTQuickTranslate
git commit -m "feat: add dual input translation controls"
```
