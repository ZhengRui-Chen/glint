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
        XCTAssertEqual(viewModel.apiSettingsLabel, L10n.apiSettings)
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
        XCTAssertTrue(viewModel.canRefreshStatus)
    }

    func test_menu_bar_keeps_translation_enabled_in_system_translation_mode() {
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            backendStatus: .system(detail: L10n.systemTranslationReady)
        )

        XCTAssertEqual(viewModel.backendHeadline, L10n.serviceStatusSystemTranslation)
        XCTAssertEqual(viewModel.backendDetail, L10n.systemTranslationReady)
        XCTAssertTrue(viewModel.canTranslateSelection)
        XCTAssertTrue(viewModel.canTranslateClipboard)
        XCTAssertTrue(viewModel.canTranslateOCR)
        XCTAssertFalse(viewModel.canRefreshStatus)
    }

    func test_menu_bar_invokes_callbacks_for_actions() {
        let recorder = MenuActionRecorder()
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            onTranslateSelection: recorder.recordSelection,
            onTranslateClipboard: recorder.recordClipboard,
            onTranslateOCR: recorder.recordOCR,
            onOpenAPISettings: recorder.recordAPISettings,
            onRefreshStatus: recorder.recordRefreshStatus,
            onOpenShortcutPanel: recorder.recordShortcutPanel,
            onQuit: recorder.recordQuit
        )

        viewModel.translateSelection()
        viewModel.translateClipboard()
        viewModel.translateOCR()
        viewModel.openAPISettings()
        viewModel.refreshStatus()
        viewModel.openKeyboardShortcuts()
        viewModel.quit()

        XCTAssertEqual(
            recorder.events,
            [
                .selection,
                .clipboard,
                .ocr,
                .apiSettings,
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
    func test_status_bar_shows_backend_status_items() throws {
        let controller = StatusBarController(statusBar: NSStatusBar()) {
            MenuBarViewModel(
                permissionStatus: .granted,
                backendStatus: .available(detail: L10n.backendReachable)
            )
        }

        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let headlineItem = try XCTUnwrap(menu.items.first { $0.title == L10n.serviceStatusAvailable })
        let detailItem = try XCTUnwrap(menu.items.first { $0.title == L10n.backendReachable })

        XCTAssertFalse(headlineItem.isEnabled)
        XCTAssertFalse(detailItem.isEnabled)
    }

    @MainActor
    func test_status_bar_disables_translation_items_when_backend_is_unavailable() throws {
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
        let apiSettingsItem = try XCTUnwrap(menu.items.first { $0.title == L10n.apiSettings })
        let refreshItem = try XCTUnwrap(menu.items.first { $0.title == L10n.refreshStatus })

        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        XCTAssertFalse(ocrItem.isEnabled)
        XCTAssertTrue(apiSettingsItem.isEnabled)
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
        case apiSettings
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

    func recordAPISettings() {
        events.append(.apiSettings)
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
