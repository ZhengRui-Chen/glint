import XCTest
@testable import Glint

final class MenuBarViewModelTests: XCTestCase {
    func test_menu_bar_exposes_permission_status() {
        let viewModel = MenuBarViewModel(permissionStatus: .required)

        XCTAssertEqual(
            viewModel.permissionLabel,
            L10n.accessibilityPermission(status: L10n.accessibilityPermissionRequired)
        )
    }

    func test_menu_bar_exposes_expected_actions() {
        let viewModel = MenuBarViewModel(permissionStatus: .granted)

        XCTAssertEqual(viewModel.translateSelectionLabel, L10n.translateSelection)
        XCTAssertEqual(viewModel.translateClipboardLabel, L10n.translateClipboard)
        XCTAssertEqual(viewModel.translateOCRLabel, L10n.translateOCRArea)
        XCTAssertEqual(viewModel.startServiceLabel, L10n.startService)
        XCTAssertEqual(viewModel.stopServiceLabel, L10n.stopService)
        XCTAssertEqual(viewModel.restartServiceLabel, L10n.restartService)
        XCTAssertEqual(viewModel.refreshStatusLabel, L10n.refreshStatus)
        XCTAssertEqual(viewModel.quitLabel, L10n.quitApp(appName: AppBranding.displayName))
    }

    @MainActor
    func test_status_bar_exposes_keyboard_shortcuts_entry_and_hides_inline_recording_items() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(permissionStatus: .granted)
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let keyboardShortcutsItem = try XCTUnwrap(
            menu.items.first { $0.title == L10n.keyboardShortcuts }
        )

        XCTAssertTrue(keyboardShortcutsItem.isEnabled)
        XCTAssertNil(menu.items.first {
            $0.title == "\(L10n.shortcutTargetSelection) Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)"
        })
        XCTAssertNil(menu.items.first {
            $0.title == "\(L10n.shortcutTargetClipboard) Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        })
        XCTAssertNil(menu.items.first { $0.title == "Cancel Shortcut Recording" })
    }

    func test_menu_bar_shows_available_backend_status() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .available(detail: L10n.backendReachable)
        )

        XCTAssertEqual(viewModel.backendHeadline, L10n.serviceStatusAvailable)
        XCTAssertEqual(viewModel.backendDetail, L10n.backendReachable)
    }

    func test_menu_bar_disables_translation_actions_when_backend_is_unavailable() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .unavailable(detail: L10n.backendCurrentlyUnavailable)
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
            backendStatus: .starting(detail: L10n.backendStartingPleaseWait)
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
            menu.items.first { $0.title == L10n.translateSelection }
        )
        let ocrItem = try XCTUnwrap(
            menu.items.first { $0.title == L10n.translateOCRArea }
        )

        XCTAssertTrue(selectionItem.isEnabled)
        XCTAssertTrue(ocrItem.isEnabled)
    }

    @MainActor
    func test_status_bar_shows_backend_panel_entry_instead_of_inline_status_items() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(
                permissionStatus: .granted,
                backendStatus: .available(detail: L10n.backendReachable)
            )
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendItem = try XCTUnwrap(menu.items.first { $0.title == L10n.backendPanelMenuItem })

        XCTAssertTrue(backendItem.isEnabled)
        XCTAssertNil(menu.items.first { $0.title == L10n.serviceStatusAvailable })
        XCTAssertNil(menu.items.first { $0.title == L10n.backendReachable })
    }

    @MainActor
    func test_status_bar_disables_translation_items_when_backend_is_unavailable_without_inline_backend_controls() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(
                permissionStatus: .granted,
                backendStatus: .unavailable(detail: L10n.backendCurrentlyUnavailable)
            )
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let selectionItem = try XCTUnwrap(menu.items.first { $0.title == L10n.translateSelection })
        let clipboardItem = try XCTUnwrap(menu.items.first { $0.title == L10n.translateClipboard })
        let ocrItem = try XCTUnwrap(menu.items.first { $0.title == L10n.translateOCRArea })
        let backendItem = try XCTUnwrap(menu.items.first { $0.title == L10n.backendPanelMenuItem })

        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        XCTAssertFalse(ocrItem.isEnabled)
        XCTAssertTrue(backendItem.isEnabled)
        XCTAssertNil(menu.items.first { $0.title == L10n.startService })
        XCTAssertNil(menu.items.first { $0.title == L10n.stopService })
        XCTAssertNil(menu.items.first { $0.title == L10n.restartService })
        XCTAssertNil(menu.items.first { $0.title == L10n.refreshStatus })
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
