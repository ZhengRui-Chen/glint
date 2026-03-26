import XCTest
@testable import HYMTQuickTranslate

final class MenuBarViewModelTests: XCTestCase {
    func test_menu_bar_exposes_permission_status() {
        let viewModel = MenuBarViewModel(permissionStatus: .required)

        XCTAssertEqual(viewModel.permissionLabel, "Accessibility Permission: Required")
    }

    func test_menu_bar_exposes_expected_actions() {
        let viewModel = MenuBarViewModel(permissionStatus: .granted)

        XCTAssertEqual(viewModel.translateSelectionLabel, "Translate Selection")
        XCTAssertEqual(viewModel.translateClipboardLabel, "Translate Clipboard")
        XCTAssertEqual(viewModel.quitLabel, "Quit HYMT Quick Translate")
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
