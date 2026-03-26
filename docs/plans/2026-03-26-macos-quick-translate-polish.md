# macOS Quick Translate Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stabilize first launch, improve overlay interaction and motion, make sizing content-aware, and add macOS 26 Liquid Glass styling where supported.

**Architecture:** Keep startup behavior changes inside the app lifecycle layer, interaction and sizing logic inside the overlay controller/UI layer, and preserve the existing translation workflow and networking stack. Add deterministic policy helpers for startup/dismissal/sizing so visual behavior does not depend on ad-hoc state checks.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, Xcode macOS app target

---

### Task 1: Fix first-launch startup reliability

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Hotkey/GlobalHotkeyMonitor.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppLaunchCoordinator.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/AppLaunchCoordinatorTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class AppLaunchCoordinatorTests: XCTestCase {
    func test_launch_coordinator_defers_hotkey_registration_until_app_is_ready() {
        let coordinator = AppLaunchCoordinator()
        XCTAssertFalse(coordinator.shouldRegisterHotkey(immediatelyAfterLaunch: true))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/AppLaunchCoordinatorTests`
Expected: FAIL because the coordinator type does not exist yet.

**Step 3: Write minimal implementation**

```swift
struct AppLaunchCoordinator {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool {
        immediatelyAfterLaunch == false
    }
}
```

Implement:

- a startup coordinator that defers hotkey registration until the app is fully initialized
- launch wiring in `AppDelegate` that schedules registration on the next main-run-loop turn if necessary
- cleanup so cold launch does not trigger early overlay or registration side effects

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/AppLaunchCoordinatorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "fix: stabilize first launch startup"
```

### Task 2: Add content-aware sizing policy for the overlay

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlaySizingPolicy.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayPanelController.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/OverlaySizingPolicyTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class OverlaySizingPolicyTests: XCTestCase {
    func test_sizing_policy_uses_compact_height_for_short_result() {
        let policy = OverlaySizingPolicy(minHeight: 180, maxHeight: 420)
        let height = policy.height(for: "Hello")
        XCTAssertEqual(height, 180)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlaySizingPolicyTests`
Expected: FAIL because the sizing policy does not exist.

**Step 3: Write minimal implementation**

```swift
struct OverlaySizingPolicy {
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func height(for text: String) -> CGFloat {
        minHeight
    }
}
```

Implement:

- deterministic size calculation based on text length and line-break heuristics
- min/max clamping
- panel resizing in `OverlayPanelController` when switching to `result`, `error`, or `confirmLongText`

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlaySizingPolicyTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add overlay sizing policy"
```

### Task 3: Improve click-away dismissal and add lightweight motion

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayDismissalPolicy.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayPanelController.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayContentView.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/OverlayPresentationBehaviorTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class OverlayPresentationBehaviorTests: XCTestCase {
    func test_dismissal_policy_allows_click_away_after_grace_period() {
        let policy = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)
        XCTAssertTrue(policy.shouldCloseOnFocusLoss(shownAt: 1.0, now: 1.5))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlayPresentationBehaviorTests`
Expected: FAIL because the new presentation-behavior test file does not exist in the target yet.

**Step 3: Write minimal implementation**

```swift
// Keep the existing dismissal helper and extend the view/controller behavior around it.
```

Implement:

- click-away dismissal that still preserves the early focus-loss grace period
- subtle fade/scale panel presentation
- content transition animation between loading/result/error/confirm states
- no animation path that hides text content or delays text rendering indefinitely

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/OverlayDismissalPolicyTests -only-testing:HYMTQuickTranslateTests/OverlayPresentationBehaviorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: refine overlay dismissal and motion"
```

### Task 4: Add macOS 26 Liquid Glass styling with fallback

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayContentView.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/SelectableTextView.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayVisualStyle.swift`
- Modify: `README.md`

**Step 1: Write the failing test or verification harness**

If direct unit testing is awkward, add a small style-selection seam:

```swift
import XCTest
@testable import HYMTQuickTranslate

final class OverlayVisualStyleTests: XCTestCase {
    func test_visual_style_uses_fallback_on_older_systems() {
        let style = OverlayVisualStyle.make(isMacOS26OrNewer: false)
        XCTAssertEqual(style, .fallback)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: FAIL because the visual-style seam does not exist yet.

**Step 3: Write minimal implementation**

```swift
enum OverlayVisualStyle: Equatable {
    case fallback
    case liquidGlass

    static func make(isMacOS26OrNewer: Bool) -> OverlayVisualStyle {
        isMacOS26OrNewer ? .liquidGlass : .fallback
    }
}
```

Implement:

- `#available(macOS 26, *)` gated glass styling
- fallback path for unsupported systems
- README note describing that advanced visual treatment depends on system version

**Step 4: Run final verification**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS

Run: `xcodebuild build -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

Run: `uv run python -m pytest -q`
Expected: PASS

Manual verification:

- cold launch app and confirm it stays alive
- immediately trigger shortcut on first launch
- verify short-result panel is compact
- verify longer text grows panel height up to a cap
- click outside the window and confirm it closes
- press `Esc` and confirm it closes
- on macOS 26, confirm glass styling is visible without hurting readability

**Step 5: Commit**

```bash
git add README.md mac-app/HYMTQuickTranslate
git commit -m "feat: polish overlay experience"
```
