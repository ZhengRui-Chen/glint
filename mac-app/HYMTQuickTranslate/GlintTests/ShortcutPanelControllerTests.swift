import Carbon.HIToolbox
import XCTest
@testable import Glint

@MainActor
final class ShortcutPanelControllerTests: XCTestCase {
    func test_controller_emits_actions_in_order() {
        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        var actions: [ShortcutPanelAction] = []
        let controller = ShortcutPanelController(shortcutSettings: .default) { action in
            actions.append(action)
        }

        controller.requestStartRecording(for: .clipboard)
        controller.requestApplyRecordedShortcut(newShortcut)
        controller.requestResetToDefaults()
        controller.requestDone()

        XCTAssertEqual(actions, [
            .startRecording(.clipboard),
            .saveRecordedShortcut(target: .clipboard, shortcut: newShortcut),
            .resetToDefaults,
            .done
        ])
    }

    func test_view_state_syncs_labels_and_recording_state_without_rebuilding_interface() {
        let updatedShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let state = ShortcutPanelViewState(shortcutSettings: .default)

        XCTAssertEqual(
            state.selectionShortcutLabel,
            "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)"
        )
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        )
        XCTAssertNil(state.recordingTarget)

        state.startRecording(for: .clipboard)
        XCTAssertEqual(state.recordingTarget, .clipboard)
        XCTAssertTrue(state.isRecordingClipboardShortcut)
        XCTAssertEqual(
            state.statusMessage,
            "Press a new shortcut, or Esc to cancel"
        )

        XCTAssertEqual(
            state.applyRecordedShortcut(updatedShortcut),
            .saved(target: .clipboard)
        )
        XCTAssertNil(state.recordingTarget)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            "Clipboard Shortcut: \(updatedShortcut.displayName)"
        )
        XCTAssertEqual(state.statusMessage, "Shortcut saved")

        state.resetToDefaults()
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        )
        XCTAssertEqual(state.statusMessage, "Defaults restored")
    }

    func test_refresh_preserves_in_progress_recording_and_transient_status() {
        let state = ShortcutPanelViewState(shortcutSettings: .default)

        state.startRecording(for: .selection)
        state.update(
            shortcutSettings: ShortcutSettings(
                clipboardShortcut: GlobalHotkeyShortcut.default,
                selectionShortcut: GlobalHotkeyShortcut(
                    keyCode: UInt32(kVK_ANSI_A),
                    modifiers: UInt32(controlKey | optionKey | cmdKey)
                )
            )
        )

        XCTAssertEqual(state.recordingTarget, .selection)
        XCTAssertTrue(state.isRecordingSelectionShortcut)
        XCTAssertEqual(
            state.statusMessage,
            "Press a new shortcut, or Esc to cancel"
        )
        XCTAssertEqual(
            state.selectionShortcutLabel,
            {
                let refreshedShortcut = GlobalHotkeyShortcut(
                    keyCode: UInt32(kVK_ANSI_A),
                    modifiers: UInt32(controlKey | optionKey | cmdKey)
                )
                return "Selection Shortcut: \(refreshedShortcut.displayName)"
            }()
        )
    }

    func test_controller_does_not_emit_save_for_duplicate_shortcuts() {
        var actions: [ShortcutPanelAction] = []
        let controller = ShortcutPanelController(shortcutSettings: .default) { action in
            actions.append(action)
        }

        controller.requestStartRecording(for: .clipboard)
        controller.requestApplyRecordedShortcut(GlobalHotkeyShortcut.selectionDefault)

        XCTAssertEqual(actions, [
            .startRecording(.clipboard)
        ])
    }
}
