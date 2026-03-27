import XCTest
@testable import Glint

final class BackendStatusMonitorTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_monitor_reports_available_when_api_is_reachable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.reachable)),
            processChecker: StubBackendProcessChecker(result: .success(true)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .available(detail: L10n.backendReachable))
    }

    func test_monitor_reports_unavailable_when_api_is_not_ready_even_if_process_is_running() async {
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

        XCTAssertEqual(snapshot, .unavailable(detail: L10n.backendCurrentlyUnavailable))
    }

    func test_monitor_reports_unavailable_when_process_and_api_are_both_unavailable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .success(false)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .unavailable(detail: L10n.backendCurrentlyUnavailable))
    }

    func test_monitor_reports_unavailable_without_process_check_when_process_fallback_is_disabled() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .failure(StubError.processFailed)),
            now: { Date(timeIntervalSince1970: 100) },
            checksProcessWhenAPIIsUnreachable: false
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .unavailable(detail: L10n.backendCurrentlyUnavailable))
    }

    func test_monitor_ignores_process_check_failures_when_api_is_unreachable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable)),
            processChecker: StubBackendProcessChecker(result: .failure(StubError.processFailed)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .unavailable(detail: L10n.backendCurrentlyUnavailable))
    }

    func test_monitor_reports_error_when_api_probe_fails() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .failure(StubError.apiFailed)),
            processChecker: StubBackendProcessChecker(result: .success(true)),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .error(detail: L10n.unableVerifyBackendStatus))
    }

    func test_api_health_checker_throws_when_request_transport_fails() async {
        let session = makeMockedSession()
        let checker = BackendAPIHealthChecker(
            urlSession: session,
            config: .default
        )
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        await XCTAssertThrowsErrorAsync(try await checker.checkAPIReachability())
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

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("MockURLProtocol.requestHandler was not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
    }
}
