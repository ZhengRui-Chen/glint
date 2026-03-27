import XCTest
@testable import Glint

final class ModelDiscoveryClientTests: XCTestCase {
    override func tearDown() {
        ModelDiscoveryMockURLProtocol.reset()
        super.tearDown()
    }

    func test_discovery_client_returns_sorted_model_ids() async throws {
        let session = makeModelDiscoveryMockedSession()
        let client = ModelDiscoveryClient(
            config: AppConfig(
                settings: APISettings(
                    baseURLString: "https://example.invalid",
                    apiKey: "test-key",
                    model: "manual-model"
                )
            ),
            session: session
        )
        ModelDiscoveryMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.invalid/v1/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data":[{"id":"z-model"},{"id":"a-model"},{"id":"m-model"}]}
            """.data(using: .utf8)!
            return (response, data)
        }

        let models = try await client.fetchModels()

        XCTAssertEqual(models, ["a-model", "m-model", "z-model"])
    }

    func test_discovery_client_throws_when_status_code_is_not_success() async {
        let session = makeModelDiscoveryMockedSession()
        let client = ModelDiscoveryClient(
            config: AppConfig(
                settings: APISettings(baseURLString: "https://example.invalid")
            ),
            session: session
        )
        ModelDiscoveryMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await XCTAssertThrowsErrorAsync(try await client.fetchModels())
    }
}

private final class ModelDiscoveryMockURLProtocol: URLProtocol {
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
            fatalError("ModelDiscoveryMockURLProtocol.requestHandler was not set")
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

private func makeModelDiscoveryMockedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ModelDiscoveryMockURLProtocol.self]
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
