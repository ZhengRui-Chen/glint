import Carbon.HIToolbox
import XCTest
@testable import Glint

@MainActor
final class ShortcutPanelControllerTests: XCTestCase {
    func test_panel_frame_anchors_to_status_item_region() {
        let frame = ShortcutPanelPlacement.frame(
            panelSize: CGSize(width: 440, height: 256),
            anchorRect: CGRect(x: 1460, y: 880, width: 24, height: 24),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 32, width: 1512, height: 918)
        )

        XCTAssertEqual(frame.origin.x, 1048, accuracy: 0.5)
        XCTAssertEqual(frame.origin.y, 692, accuracy: 0.5)
    }

    func test_controller_emits_actions_in_order() {
        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        var actions: [ShortcutPanelAction] = []
        let controller = ShortcutPanelController(shortcutSettings: .default) { action in
            actions.append(action)
            return true
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
            GlobalHotkeyShortcut.selectionDefault.displayName
        )
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            GlobalHotkeyShortcut.default.displayName
        )
        XCTAssertNil(state.recordingTarget)

        state.startRecording(for: .clipboard)
        XCTAssertEqual(state.recordingTarget, .clipboard)
        XCTAssertTrue(state.isRecordingClipboardShortcut)
        XCTAssertEqual(
            state.statusMessage,
            "Press a shortcut. Esc cancels."
        )

        XCTAssertEqual(
            state.applyRecordedShortcut(updatedShortcut),
            .saved(target: .clipboard)
        )
        XCTAssertEqual(state.recordingTarget, .clipboard)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            updatedShortcut.displayName
        )

        state.commitRecordedShortcut(updatedShortcut, for: .clipboard)
        XCTAssertNil(state.recordingTarget)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            updatedShortcut.displayName
        )
        XCTAssertEqual(state.statusMessage, "Shortcut saved")

        state.resetToDefaults()
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            GlobalHotkeyShortcut.default.displayName
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
            "Press a shortcut. Esc cancels."
        )
        XCTAssertEqual(
            state.selectionShortcutLabel,
            {
                let refreshedShortcut = GlobalHotkeyShortcut(
                    keyCode: UInt32(kVK_ANSI_A),
                    modifiers: UInt32(controlKey | optionKey | cmdKey)
                )
                return refreshedShortcut.displayName
            }()
        )
    }

    func test_controller_does_not_emit_save_for_duplicate_shortcuts() {
        var actions: [ShortcutPanelAction] = []
        let controller = ShortcutPanelController(shortcutSettings: .default) { action in
            actions.append(action)
            return true
        }

        controller.requestStartRecording(for: .clipboard)
        controller.requestApplyRecordedShortcut(GlobalHotkeyShortcut.selectionDefault)

        XCTAssertEqual(actions, [
            .startRecording(.clipboard)
        ])
    }

    func test_controller_keeps_recording_state_when_panel_save_fails() throws {
        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        var actions: [ShortcutPanelAction] = []
        let controller = ShortcutPanelController(shortcutSettings: .default) { action in
            actions.append(action)
            if case .saveRecordedShortcut = action {
                return false
            }
            return true
        }

        controller.requestStartRecording(for: .clipboard)
        controller.requestApplyRecordedShortcut(newShortcut)

        let state = controller.testingSnapshot
        XCTAssertEqual(
            actions,
            [
                .startRecording(.clipboard),
                .saveRecordedShortcut(target: .clipboard, shortcut: newShortcut)
            ]
        )
        XCTAssertEqual(state.recordingTarget, .clipboard)
        XCTAssertEqual(
            state.statusMessage,
            "Shortcut could not be registered. Try another combination."
        )
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            newShortcut.displayName
        )
    }

    func test_escape_cancels_recording_without_closing_panel() {
        let controller = ShortcutPanelController(shortcutSettings: .default)

        controller.show()
        controller.requestStartRecording(for: .selection)
        controller.previewModifierInputForTesting(UInt32(controlKey | optionKey))
        controller.handleCancelForTesting()

        let state = controller.testingSnapshot
        XCTAssertTrue(controller.isPanelVisibleForTesting)
        XCTAssertNil(state.recordingTarget)
        XCTAssertNil(state.statusMessage)
        XCTAssertEqual(
            state.selectionShortcutLabel,
            GlobalHotkeyShortcut.selectionDefault.displayName
        )

        controller.closePanel()
    }

    func test_escape_closes_panel_when_not_recording() {
        let controller = ShortcutPanelController(shortcutSettings: .default)

        controller.show()
        controller.handleCancelForTesting()

        let didClose = expectation(description: "panel closes after escape")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if controller.isPanelVisibleForTesting == false {
                didClose.fulfill()
            }
        }

        wait(for: [didClose], timeout: 1)
    }

    func test_controller_clears_recording_state_when_done_or_closed() throws {
        let controller = ShortcutPanelController(shortcutSettings: .default)

        controller.requestStartRecording(for: .selection)
        controller.requestDone()

        let doneState = controller.testingSnapshot
        XCTAssertNil(doneState.recordingTarget)
        XCTAssertNil(doneState.statusMessage)

        controller.requestStartRecording(for: .clipboard)
        controller.closePanel()

        let closedState = controller.testingSnapshot
        XCTAssertNil(closedState.recordingTarget)
        XCTAssertNil(closedState.statusMessage)
    }
}
