import Carbon.HIToolbox
import XCTest
@testable import Glint

final class GlobalHotkeyMonitorTests: XCTestCase {
    func test_hotkey_callback_invokes_workflow() {
        let recorder = WorkflowRecorder()
        let monitor = GlobalHotkeyMonitor(onTrigger: recorder.record)

        monitor.invokeForTesting()

        XCTAssertEqual(recorder.callCount, 1)
    }

    func test_start_reports_registration_failure() {
        let monitor = GlobalHotkeyMonitor(
            onTrigger: {},
            simulatedRegistrationResult: { _ in false }
        )

        XCTAssertFalse(monitor.start())
    }

    func test_reload_restores_previous_shortcut_when_registration_fails() {
        let candidateShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        var attemptedShortcuts: [GlobalHotkeyShortcut] = []
        var registrationResults = [true, false, true]
        let monitor = GlobalHotkeyMonitor(
            onTrigger: {},
            simulatedRegistrationResult: { shortcut in
                attemptedShortcuts.append(shortcut)
                return registrationResults.removeFirst()
            }
        )

        XCTAssertTrue(monitor.start())
        XCTAssertFalse(monitor.reload(shortcut: candidateShortcut))

        XCTAssertEqual(
            attemptedShortcuts,
            [
                .default,
                candidateShortcut,
                .default,
            ]
        )
    }
}

private final class WorkflowRecorder {
    private(set) var callCount = 0

    func record() {
        callCount += 1
    }
}
