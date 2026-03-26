import XCTest
@testable import Glint

final class BackendStatusMonitorTests: XCTestCase {
    func test_monitor_reports_available_when_api_is_reachable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.reachable)),
            processChecker: StubBackendProcessChecker(result: .success(true)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .available(detail: "Translation backend is reachable"))
    }

    func test_monitor_reports_starting_when_recent_start_has_running_process_but_api_is_not_ready() async {
        let now = Date(timeIntervalSince1970: 100)
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .success(true)),
            now: { now }
        )

        let snapshot = await monitor.refresh(
            actionContext: BackendActionContext(
                action: .start,
                requestedAt: now.addingTimeInterval(-5)
            )
        )

        XCTAssertEqual(snapshot, .starting(detail: "Backend is starting, please wait"))
    }

    func test_monitor_reports_unavailable_when_process_and_api_are_both_unavailable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .success(false)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .unavailable(detail: "Backend is currently unavailable"))
    }

    func test_monitor_reports_error_when_process_check_fails() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .failure(StubError.processFailed)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .error(detail: "Unable to verify backend status"))
    }

    func test_monitor_reports_error_when_api_probe_fails() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .failure(StubError.apiFailed)),
            processChecker: StubBackendProcessChecker(result: .success(true)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .error(detail: "Unable to verify backend status"))
    }
}

private struct StubBackendAPIHealthChecker: BackendAPIHealthChecking {
    let result: Result<BackendAPIReachability, Error>

    func checkAPIReachability() async throws -> BackendAPIReachability {
        try result.get()
    }
}

private struct StubBackendProcessChecker: BackendProcessChecking {
    let result: Result<Bool, Error>

    func isBackendProcessRunning() async throws -> Bool {
        try result.get()
    }
}

private enum StubError: Error {
    case apiFailed
    case processFailed
}
