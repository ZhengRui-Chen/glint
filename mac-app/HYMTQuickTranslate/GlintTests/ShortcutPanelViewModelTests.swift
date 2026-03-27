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

    func test_cancel_clears_active_recording_state() {
        let viewModel = ShortcutPanelViewModel(shortcutSettings: .default)

        viewModel.startRecording(for: .clipboard)
        viewModel.cancelRecording()

        XCTAssertNil(viewModel.recordingTarget)
        XCTAssertNil(viewModel.statusMessage)
    }

    func test_custom_settings_are_reflected_in_visible_labels() {
        let customSettings = ShortcutSettings(
            clipboardShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_X),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            ),
            selectionShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_Y),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            )
        )
        let viewModel = ShortcutPanelViewModel(shortcutSettings: customSettings)

        XCTAssertEqual(
            viewModel.clipboardShortcutLabel,
            "Clipboard Shortcut: \(customSettings.clipboardShortcut.displayName)"
        )
        XCTAssertEqual(
            viewModel.selectionShortcutLabel,
            "Selection Shortcut: \(customSettings.selectionShortcut.displayName)"
        )
    }

    func test_reset_restores_both_defaults_with_feedback_message() {
        let customizedSettings = ShortcutSettings(
            clipboardShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_X),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            ),
            selectionShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_Y),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            )
        )
        let viewModel = ShortcutPanelViewModel(shortcutSettings: customizedSettings)

        viewModel.startRecording(for: .clipboard)
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
