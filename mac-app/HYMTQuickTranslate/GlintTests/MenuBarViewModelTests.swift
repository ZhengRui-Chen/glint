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
        XCTAssertEqual(viewModel.quitLabel, "Quit Glint")
    }

    func test_menu_bar_invokes_callbacks_for_actions() {
        let recorder = MenuActionRecorder()
        let viewModel = MenuBarViewModel(
            permissionStatus: .granted,
            onTranslateSelection: recorder.recordSelection,
            onTranslateClipboard: recorder.recordClipboard,
            onQuit: recorder.recordQuit
        )

        viewModel.translateSelection()
        viewModel.translateClipboard()
        viewModel.quit()

        XCTAssertEqual(recorder.events, [.selection, .clipboard, .quit])
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

        XCTAssertTrue(selectionItem.isEnabled)
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
        case quit
    }

    private(set) var events: [Event] = []

    func recordSelection() {
        events.append(.selection)
    }

    func recordClipboard() {
        events.append(.clipboard)
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
