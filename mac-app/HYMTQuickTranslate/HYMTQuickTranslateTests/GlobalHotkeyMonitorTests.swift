import XCTest
@testable import HYMTQuickTranslate

final class GlobalHotkeyMonitorTests: XCTestCase {
    func test_hotkey_callback_invokes_workflow() {
        let recorder = WorkflowRecorder()
        let monitor = GlobalHotkeyMonitor(onTrigger: recorder.record)

        monitor.invokeForTesting()

        XCTAssertEqual(recorder.callCount, 1)
    }
}

private final class WorkflowRecorder {
    private(set) var callCount = 0

    func record() {
        callCount += 1
    }
}
