# Backend Status Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a backend availability section and basic backend management actions to the Glint macOS menu bar app so users can see whether translation is usable and recover it directly from the menu.

**Architecture:** Keep the menu bar icon unchanged and add a backend-specific state slice behind `MenuBarViewModel`. Use a testable backend monitor for API and process checks, a control service for start and stop scripts, and an `AppDelegate`-owned refresh loop that feeds compact menu-ready state into the existing AppKit menu builder.

**Tech Stack:** Swift 6, AppKit, XCTest, `URLSession`, `Process`, existing backend shell scripts

---

### Task 1: Add the backend status model and menu-state tests

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`

**Step 1: Write the failing tests**

Add tests that prove the menu:

- shows `Service Status: Available` for an available backend
- disables `Translate Selection` and `Translate Clipboard` when unavailable
- enables and disables `Start Service`, `Stop Service`, `Restart Service`, and `Refresh Status` according to the backend state

Example test additions:

```swift
func test_menu_bar_shows_available_backend_status() throws {
    let viewModel = MenuBarViewModel(
        permissionStatus: .granted,
        backendStatus: .available(detail: "Translation backend is reachable")
    )

    XCTAssertEqual(viewModel.backendHeadline, "Service Status: Available")
    XCTAssertEqual(viewModel.backendDetail, "Translation backend is reachable")
}

@MainActor
func test_status_bar_disables_translation_items_when_backend_is_unavailable() throws {
    let controller = StatusBarController(statusBar: NSStatusBar()) {
        MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .unavailable(detail: "Backend is currently unavailable")
        )
    }

    let menu = try XCTUnwrap(reflectedMenu(from: controller))
    let selectionItem = try XCTUnwrap(menu.items.first { $0.title == "Translate Selection" })
    let clipboardItem = try XCTUnwrap(menu.items.first { $0.title == "Translate Clipboard" })

    XCTAssertFalse(selectionItem.isEnabled)
    XCTAssertFalse(clipboardItem.isEnabled)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests`

Expected: FAIL because `MenuBarViewModel` does not yet have backend status properties or action labels.

**Step 3: Write minimal implementation**

Create a backend snapshot model that can represent:

- `checking`
- `available`
- `starting`
- `unavailable`
- `error`

Extend `MenuBarViewModel` with:

- `backendHeadline`
- `backendDetail`
- enable and disable rules for translation items
- labels and availability flags for backend actions

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests`

Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusSnapshot.swift \
  mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift \
  mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift
git commit -m "test: add backend menu state coverage"
```

### Task 2: Build a testable backend monitor

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendStatusMonitor.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendHealthChecker.swift`
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/ShellCommandRunner.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/BackendStatusMonitorTests.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/Config/AppConfig.swift`

**Step 1: Write the failing tests**

Add monitor tests that prove:

- reachable API maps to `.available`
- recent start action with process present but API not ready maps to `.starting`
- no process and no API maps to `.unavailable`
- shell or probe failures map to `.error`

Example test:

```swift
func test_monitor_reports_available_when_api_is_reachable() async throws {
    let monitor = BackendStatusMonitor(
        apiChecker: StubAPIChecker(result: .reachable),
        processChecker: StubProcessChecker(isRunning: true),
        now: { Date(timeIntervalSince1970: 0) }
    )

    let snapshot = try await monitor.refresh()

    XCTAssertEqual(snapshot, .available(detail: "Translation backend is reachable"))
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendStatusMonitorTests`

Expected: FAIL because no backend monitor or health checker exists yet.

**Step 3: Write minimal implementation**

Implement:

- an API probe against `AppConfig.default.baseURL.appending(path: "/v1/models")`
- a lightweight process check using `/usr/bin/pgrep -f "omlx serve --model-dir"`
- a monitor that converts those signals plus recent action context into a `BackendStatusSnapshot`

Add AppConfig values for:

- backend status refresh interval
- backend API timeout

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendStatusMonitorTests`

Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/Backend \
  mac-app/HYMTQuickTranslate/Glint/Config/AppConfig.swift \
  mac-app/HYMTQuickTranslate/GlintTests/BackendStatusMonitorTests.swift
git commit -m "feat: add backend status monitor"
```

### Task 3: Add backend control actions and wire them into the menu

**Files:**
- Create: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendControlService.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/MenuBarViewModel.swift`
- Modify: `mac-app/HYMTQuickTranslate/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/HYMTQuickTranslate/GlintTests/MenuBarViewModelTests.swift`
- Create: `mac-app/HYMTQuickTranslate/GlintTests/BackendControlServiceTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:

- `Start Service` runs the start script and transitions the menu into `.starting`
- `Stop Service` runs the stop script and disables translation entries
- `Restart Service` runs the restart script and temporarily disables conflicting actions
- `Refresh Status` triggers a status refresh callback

Example test:

```swift
func test_control_service_runs_restart_script() async throws {
    let runner = RecordingCommandRunner()
    let service = BackendControlService(commandRunner: runner)

    try await service.restart()

    XCTAssertEqual(
        runner.commands,
        [["zsh", "scripts/restart_omlx.sh"]]
    )
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendControlServiceTests -only-testing:GlintTests/MenuBarViewModelTests`

Expected: FAIL because the control service and backend action wiring do not exist yet.

**Step 3: Write minimal implementation**

Implement a control service that runs:

- `zsh scripts/start_omlx_tmux.sh`
- `zsh scripts/stop_omlx.sh`
- `zsh scripts/restart_omlx.sh`

Wire `AppDelegate` to:

- own a monitor and control service
- refresh backend state on launch and on menu open
- expose callbacks into `MenuBarViewModel`

Update `StatusBarController` so it renders:

- backend headline item
- backend detail item
- backend action items
- disabled translation items when the backend is not available

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/BackendControlServiceTests -only-testing:GlintTests/MenuBarViewModelTests`

Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift \
  mac-app/HYMTQuickTranslate/Glint/MenuBar \
  mac-app/HYMTQuickTranslate/Glint/Backend/BackendControlService.swift \
  mac-app/HYMTQuickTranslate/GlintTests
git commit -m "feat: add backend controls to menu bar"
```

### Task 4: Add refresh timing and final polish

**Files:**
- Modify: `mac-app/HYMTQuickTranslate/Glint/App/AppDelegate.swift`
- Modify: `README.md`
- Modify: `scripts/build_mac_app.sh`
- Modify: `docs/plans/2026-03-26-backend-status-menu-design.md`
- Modify: `docs/plans/2026-03-26-backend-status-menu.md`

**Step 1: Write the failing tests**

Add tests that prove:

- opening the menu refreshes backend state
- background refresh keeps the latest snapshot current
- existing shortcut and translation behavior remains intact

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: FAIL until refresh timing and integration wiring are complete.

**Step 3: Write minimal implementation**

Implement:

- low-frequency timer refresh in `AppDelegate`
- immediate refresh when the menu opens
- small menu polish such as section ordering and concise detail copy
- documentation updates if menu behavior descriptions need to mention backend status and management actions

Implementation notes:

- keep the refresh loop on the main run loop because the menu model is rebuilt on the main actor
- use the existing `AppConfig.default.backendStatusRefreshInterval` value, which is 15 seconds
- do not churn `scripts/build_mac_app.sh` unless the new menu wiring actually requires a packaging change

**Step 4: Run test to verify it passes**

Run:

- `uv run pytest -q`
- `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
- `zsh scripts/build_mac_app.sh`

Expected:

- Python tests PASS
- macOS tests PASS
- local app bundle build succeeds

**Step 5: Commit**

```bash
git add README.md scripts/build_mac_app.sh mac-app/HYMTQuickTranslate/Glint docs/plans
git commit -m "feat: expose backend status in menu bar"
```
