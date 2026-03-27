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

    func test_multiple_monitors_do_not_swallow_other_hotkey_events() throws {
        let clipboardRecorder = WorkflowRecorder()
        let selectionRecorder = WorkflowRecorder()
        let clipboardMonitor = GlobalHotkeyMonitor(
            identifier: 1,
            onTrigger: clipboardRecorder.record,
            simulatedRegistrationResult: { _ in true }
        )
        let selectionMonitor = GlobalHotkeyMonitor(
            identifier: 2,
            onTrigger: selectionRecorder.record,
            simulatedRegistrationResult: { _ in true }
        )
        defer {
            selectionMonitor.stop()
            clipboardMonitor.stop()
        }

        XCTAssertTrue(clipboardMonitor.start())
        XCTAssertTrue(selectionMonitor.start())

        try dispatchHotkeyPressedEvent(identifier: 1)

        XCTAssertEqual(clipboardRecorder.callCount, 1)
        XCTAssertEqual(selectionRecorder.callCount, 0)
    }
}

private final class WorkflowRecorder {
    private(set) var callCount = 0

    func record() {
        callCount += 1
    }
}

private func dispatchHotkeyPressedEvent(identifier: UInt32) throws {
    var eventRef: EventRef?
    let createStatus = CreateEvent(
        nil,
        UInt32(kEventClassKeyboard),
        UInt32(kEventHotKeyPressed),
        GetCurrentEventTime(),
        EventAttributes(),
        &eventRef
    )
    XCTAssertEqual(createStatus, noErr)
    guard let eventRef else {
        throw NSError(domain: "GlobalHotkeyMonitorTests", code: Int(createStatus))
    }
    defer {
        ReleaseEvent(eventRef)
    }

    var hotKeyID = EventHotKeyID(signature: OSType(0x48594D54), id: identifier)
    let setStatus = SetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        MemoryLayout<EventHotKeyID>.size,
        &hotKeyID
    )
    XCTAssertEqual(setStatus, noErr)

    let dispatchStatus = SendEventToEventTarget(eventRef, GetApplicationEventTarget())
    XCTAssertEqual(dispatchStatus, noErr)
}
