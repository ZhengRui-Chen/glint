import XCTest
@testable import Glint

final class BackendStatusMonitorTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_monitor_reports_available_when_api_is_reachable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.reachable))
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .available(detail: L10n.backendReachable))
    }

    func test_monitor_reports_unavailable_when_api_is_not_reachable() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .success(.unreachable))
        )

        let snapshot = await monitor.refresh()

        XCTAssertEqual(snapshot, .unavailable(detail: L10n.backendCurrentlyUnavailable))
    }

    func test_monitor_reports_error_when_api_probe_fails() async {
        let monitor = BackendStatusMonitor(
            apiChecker: StubBackendAPIHealthChecker(result: .failure(StubError.apiFailed))
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

    func test_api_health_checker_uses_latest_saved_runtime_settings() async throws {
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = APISettingsStore(userDefaults: userDefaults)
        let source = RuntimeAppConfigSource(store: store)
        let session = makeMockedSession()
        let checker = BackendAPIHealthChecker(
            urlSession: session,
            configProvider: source.load
        )

        store.save(
            APISettings(
                baseURLString: "https://runtime.invalid",
                apiKey: "runtime-key",
                model: "runtime-model"
            )
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://runtime.invalid/v1/models")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer runtime-key"
            )
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let reachability = try await checker.checkAPIReachability()

        XCTAssertEqual(reachability, .reachable)
    }
}

private struct StubBackendAPIHealthChecker: BackendAPIHealthChecking {
    let result: Result<BackendAPIReachability, Error>

    func checkAPIReachability() async throws -> BackendAPIReachability {
        try result.get()
    }
}

private enum StubError: Error {
    case apiFailed
}

private final class RuntimeAppConfigSource: @unchecked Sendable {
    private let store: APISettingsStore

    init(store: APISettingsStore) {
        self.store = store
    }

    func load() -> AppConfig {
        AppConfig(settings: store.load())
    }
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
