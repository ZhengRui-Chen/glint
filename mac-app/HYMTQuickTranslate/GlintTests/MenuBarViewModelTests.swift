import XCTest
@testable import Glint

final class MenuBarViewModelTests: XCTestCase {
    func test_menu_bar_exposes_permission_status() {
        let viewModel = MenuBarViewModel(permissionStatus: .required)

        XCTAssertEqual(viewModel.permissionLabel, "Accessibility Permission: Required")
    }

    func test_menu_bar_exposes_expected_actions() {
        let viewModel = MenuBarViewModel(permissionStatus: .granted)

        XCTAssertEqual(viewModel.translateSelectionLabel, "Translate Selection")
        XCTAssertEqual(viewModel.translateClipboardLabel, "Translate Clipboard")
        XCTAssertEqual(viewModel.translateOCRLabel, "Translate OCR Area")
        XCTAssertEqual(viewModel.startServiceLabel, "Start Service")
        XCTAssertEqual(viewModel.stopServiceLabel, "Stop Service")
        XCTAssertEqual(viewModel.restartServiceLabel, "Restart Service")
        XCTAssertEqual(viewModel.refreshStatusLabel, "Refresh Status")
        XCTAssertEqual(viewModel.quitLabel, "Quit Glint")
    }

    @MainActor
    func test_status_bar_exposes_keyboard_shortcuts_entry_and_hides_inline_recording_items() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(permissionStatus: .granted)
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let keyboardShortcutsItem = try XCTUnwrap(
            menu.items.first { $0.title == "Keyboard Shortcuts…" }
        )

        XCTAssertTrue(keyboardShortcutsItem.isEnabled)
        XCTAssertNil(menu.items.first { $0.title == "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)" })
        XCTAssertNil(menu.items.first { $0.title == "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)" })
        XCTAssertNil(menu.items.first { $0.title == "Cancel Shortcut Recording" })
    }

    func test_menu_bar_shows_available_backend_status() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .available(detail: "Translation backend is reachable")
        )

        XCTAssertEqual(viewModel.backendHeadline, "Service Status: Available")
        XCTAssertEqual(viewModel.backendDetail, "Translation backend is reachable")
    }

    func test_menu_bar_disables_translation_actions_when_backend_is_unavailable() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .unavailable(detail: "Backend is currently unavailable")
        )

        XCTAssertFalse(viewModel.canTranslateSelection)
        XCTAssertFalse(viewModel.canTranslateClipboard)
        XCTAssertFalse(viewModel.canTranslateOCR)
        XCTAssertTrue(viewModel.canStartService)
        XCTAssertFalse(viewModel.canStopService)
        XCTAssertTrue(viewModel.canRestartService)
        XCTAssertTrue(viewModel.canRefreshStatus)
    }

    func test_menu_bar_disables_conflicting_actions_while_backend_is_starting() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .starting(detail: "Backend is starting, please wait")
        )

        XCTAssertFalse(viewModel.canTranslateSelection)
        XCTAssertFalse(viewModel.canTranslateClipboard)
        XCTAssertFalse(viewModel.canTranslateOCR)
        XCTAssertFalse(viewModel.canStartService)
        XCTAssertTrue(viewModel.canStopService)
        XCTAssertFalse(viewModel.canRestartService)
        XCTAssertFalse(viewModel.canRefreshStatus)
    }

    func test_menu_bar_invokes_callbacks_for_actions() {
        let recorder = MenuActionRecorder()
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            onTranslateSelection: recorder.recordSelection,
            onTranslateClipboard: recorder.recordClipboard,
            onTranslateOCR: recorder.recordOCR,
            onStartService: recorder.recordStartService,
            onStopService: recorder.recordStopService,
            onRestartService: recorder.recordRestartService,
            onRefreshStatus: recorder.recordRefreshStatus,
            onOpenShortcutPanel: recorder.recordShortcutPanel,
            onQuit: recorder.recordQuit
        )

        viewModel.translateSelection()
        viewModel.translateClipboard()
        viewModel.translateOCR()
        viewModel.startService()
        viewModel.stopService()
        viewModel.restartService()
        viewModel.refreshStatus()
        viewModel.openKeyboardShortcuts()
        viewModel.quit()

        XCTAssertEqual(
            recorder.events,
            [
                .selection,
                .clipboard,
                .ocr,
                .startService,
                .stopService,
                .restartService,
                .refreshStatus,
                .keyboardShortcuts,
                .quit
            ]
        )
    }

    @MainActor
    func test_status_bar_keeps_selection_item_enabled_when_permission_is_required() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(permissionStatus: .required)
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let selectionItem = try XCTUnwrap(
            menu.items.first { $0.title == "Translate Selection" }
        )
        let ocrItem = try XCTUnwrap(
            menu.items.first { $0.title == "Translate OCR Area" }
        )

        XCTAssertTrue(selectionItem.isEnabled)
        XCTAssertTrue(ocrItem.isEnabled)
    }

    @MainActor
    func test_status_bar_shows_backend_status_items() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(
                permissionStatus: .granted,
                backendStatus: .available(detail: "Translation backend is reachable")
            )
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let headlineItem = try XCTUnwrap(menu.items.first { $0.title == "Service Status: Available" })
        let detailItem = try XCTUnwrap(menu.items.first { $0.title == "Translation backend is reachable" })

        XCTAssertFalse(headlineItem.isEnabled)
        XCTAssertFalse(detailItem.isEnabled)
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
        let ocrItem = try XCTUnwrap(menu.items.first { $0.title == "Translate OCR Area" })
        let startItem = try XCTUnwrap(menu.items.first { $0.title == "Start Service" })
        let stopItem = try XCTUnwrap(menu.items.first { $0.title == "Stop Service" })
        let restartItem = try XCTUnwrap(menu.items.first { $0.title == "Restart Service" })
        let refreshItem = try XCTUnwrap(menu.items.first { $0.title == "Refresh Status" })

        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        XCTAssertFalse(ocrItem.isEnabled)
        XCTAssertTrue(startItem.isEnabled)
        XCTAssertFalse(stopItem.isEnabled)
        XCTAssertTrue(restartItem.isEnabled)
        XCTAssertTrue(refreshItem.isEnabled)
    }

    @MainActor
    func test_status_bar_uses_glint_template_icon() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(permissionStatus: .granted)
        }

        let statusItem = try XCTUnwrap(reflectedStatusItem(from: controller))
        let button = try XCTUnwrap(statusItem.button)
        let image = try XCTUnwrap(button.image)

        XCTAssertEqual(button.title, "")
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(button.toolTip, "Glint")
    }
}

private final class MenuActionRecorder {
    enum Event: Equatable {
        case selection
        case clipboard
        case ocr
        case startService
        case stopService
        case restartService
        case refreshStatus
        case keyboardShortcuts
        case quit
    }

    private(set) var events: [Event] = []

    func recordSelection() {
        events.append(.selection)
    }

    func recordClipboard() {
        events.append(.clipboard)
    }

    func recordOCR() {
        events.append(.ocr)
    }

    func recordStartService() {
        events.append(.startService)
    }

    func recordStopService() {
        events.append(.stopService)
    }

    func recordRestartService() {
        events.append(.restartService)
    }

    func recordRefreshStatus() {
        events.append(.refreshStatus)
    }

    func recordShortcutPanel() {
        events.append(.keyboardShortcuts)
    }

    func recordQuit() {
        events.append(.quit)
    }
}

private func reflectedMenu(from controller: StatusBarController) -> NSMenu? {
    Mirror(reflecting: controller).children
        .first { $0.label == "menu" }?
        .value as? NSMenu
}

private func reflectedStatusItem(from controller: StatusBarController) -> NSStatusItem? {
    Mirror(reflecting: controller).children
        .first { $0.label == "statusItem" }?
        .value as? NSStatusItem
}
