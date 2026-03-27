import Carbon.HIToolbox
import XCTest
@testable import Glint

@MainActor
final class ShortcutPanelViewModelTests: XCTestCase {
    func test_idle_state_exposes_current_shortcuts_and_no_active_recording() {
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        XCTAssertEqual(
            viewModel.selectionShortcutLabel,
            "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)"
        )
        XCTAssertEqual(
            viewModel.clipboardShortcutLabel,
            "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        )
        XCTAssertNil(viewModel.recordingTarget)
        XCTAssertFalse(viewModel.isRecordingSelectionShortcut)
        XCTAssertFalse(viewModel.isRecordingClipboardShortcut)
        XCTAssertNil(viewModel.statusMessage)
    }

    func test_starting_recording_marks_only_one_target_active() {
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        viewModel.startRecording(for: .clipboard)

        XCTAssertEqual(viewModel.recordingTarget, .clipboard)
        XCTAssertFalse(viewModel.isRecordingSelectionShortcut)
        XCTAssertTrue(viewModel.isRecordingClipboardShortcut)
        XCTAssertEqual(
            viewModel.statusMessage,
            "Press a new shortcut, or Esc to cancel"
        )
    }

    func test_duplicate_shortcuts_surface_a_hard_error_message() {
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        viewModel.startRecording(for: .clipboard)
        viewModel.applyRecordedShortcut(GlobalHotkeyShortcut.selectionDefault)

        XCTAssertEqual(viewModel.recordingTarget, .clipboard)
        XCTAssertEqual(
            viewModel.statusMessage,
            "This shortcut is already used by Glint"
        )
        XCTAssertEqual(
            viewModel.clipboardShortcutLabel,
            "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        )
    }

    func test_successful_save_updates_visible_shortcut_and_feedback_message() {
        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        viewModel.startRecording(for: .clipboard)
        viewModel.applyRecordedShortcut(newShortcut)

        XCTAssertNil(viewModel.recordingTarget)
        XCTAssertEqual(
            viewModel.clipboardShortcutLabel,
            "Clipboard Shortcut: \(newShortcut.displayName)"
        )
        XCTAssertEqual(viewModel.selectionShortcutLabel, "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)")
        XCTAssertEqual(viewModel.statusMessage, "Shortcut saved")
    }

    func test_reset_restores_both_defaults_with_feedback_message() {
        let updatedShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        viewModel.startRecording(for: .clipboard)
        viewModel.applyRecordedShortcut(updatedShortcut)
        viewModel.resetToDefaults()

        XCTAssertNil(viewModel.recordingTarget)
        XCTAssertEqual(
            viewModel.selectionShortcutLabel,
            "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)"
        )
        XCTAssertEqual(
            viewModel.clipboardShortcutLabel,
            "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        )
        XCTAssertEqual(viewModel.statusMessage, "Defaults restored")
    }
}
