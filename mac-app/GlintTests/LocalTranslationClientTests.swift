import XCTest
@testable import Glint

final class LocalTranslationClientTests: XCTestCase {
    override func tearDown() {
        LocalTranslationClientMockURLProtocol.reset()
        super.tearDown()
    }

    func test_client_decodes_first_choice_content() throws {
        let data = """
        {"choices":[{"message":{"content":"很高兴见到你。"}}]}
        """.data(using: .utf8)!
        let decoded = try LocalTranslationClient.decodeContent(from: data)
        XCTAssertEqual(decoded, "很高兴见到你。")
    }

    func test_client_throws_missing_configuration_when_base_url_is_not_set() async {
        let session = makeLocalTranslationClientMockedSession()
        let client = LocalTranslationClient(
            config: AppConfig(settings: APISettings(baseURLString: "", model: "gpt-test")),
            session: session
        )
        LocalTranslationClientMockURLProtocol.requestHandler = { _ in
            XCTFail("Request should not be sent when configuration is missing")
            throw URLError(.badURL)
        }

        await XCTAssertLocalTranslationThrowsErrorAsync(
            try await client.translate(text: "hello", direction: .enToZh),
            expected: .missingConfiguration
        )
    }

    func test_client_uses_runtime_api_settings_for_request() async throws {
        let session = makeLocalTranslationClientMockedSession()
        let client = LocalTranslationClient(
            config: AppConfig(
                settings: APISettings(
                    baseURLString: "https://example.invalid",
                    apiKey: "runtime-key",
                    model: "runtime-model"
                )
            ),
            session: session
        )
        LocalTranslationClientMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.invalid/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer runtime-key")

            let payload = try XCTUnwrap(requestBody(from: request))
            let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: payload)
            XCTAssertEqual(decoded.model, "runtime-model")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"choices":[{"message":{"content":"translated"}}]}
            """.data(using: .utf8)!
            return (response, data)
        }

        let translated = try await client.translate(text: "hello", direction: .enToZh)

        XCTAssertEqual(translated, "translated")
    }

    func test_client_uses_latest_saved_runtime_settings() async throws {
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = APISettingsStore(userDefaults: userDefaults)
        let source = RuntimeTranslationConfigSource(store: store)
        let session = makeLocalTranslationClientMockedSession()
        let client = LocalTranslationClient(
            session: session,
            configProvider: source.load
        )

        store.save(
            APISettings(
                baseURLString: "https://runtime.invalid",
                apiKey: "fresh-key",
                model: "fresh-model"
            )
        )

        LocalTranslationClientMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://runtime.invalid/v1/chat/completions"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-key")

            let payload = try XCTUnwrap(requestBody(from: request))
            let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: payload)
            XCTAssertEqual(decoded.model, "fresh-model")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"choices":[{"message":{"content":"runtime translation"}}]}
            """.data(using: .utf8)!
            return (response, data)
        }

        let translated = try await client.translate(text: "hello", direction: .enToZh)

        XCTAssertEqual(translated, "runtime translation")
    }

    func test_runtime_client_routes_custom_api_requests_to_http_client() async throws {
        let customAPIClient = RecordingTranslationClient(result: "custom-result")
        let systemClient = RecordingTranslationClient(result: "system-result")
        let client = RuntimeTranslationClient(
            configProvider: {
                AppConfig(
                    settings: APISettings(
                        provider: .customAPI,
                        baseURLString: "https://example.invalid/v1",
                        apiKey: "test-key",
                        model: "test-model"
                    )
                )
            },
            makeCustomAPIClient: { _ in customAPIClient },
            systemTranslationClient: systemClient
        )

        let translated = try await client.translate(text: "hello", direction: .enToZh)

        XCTAssertEqual(translated, "custom-result")
        let customCalls = await customAPIClient.recordedCalls()
        let systemCalls = await systemClient.recordedCalls()
        XCTAssertEqual(customCalls, [.init(text: "hello", direction: .enToZh)])
        XCTAssertTrue(systemCalls.isEmpty)
    }

    func test_runtime_client_routes_system_requests_to_system_translation_client() async throws {
        let customAPIClient = RecordingTranslationClient(result: "custom-result")
        let systemClient = RecordingTranslationClient(result: "system-result")
        let client = RuntimeTranslationClient(
            configProvider: {
                AppConfig(
                    settings: APISettings(
                        provider: .system,
                        baseURLString: "https://ignored.invalid/v1",
                        apiKey: "ignored-key",
                        model: "ignored-model"
                    )
                )
            },
            makeCustomAPIClient: { _ in customAPIClient },
            systemTranslationClient: systemClient
        )

        let translated = try await client.translate(text: "你好", direction: .zhToEn)

        XCTAssertEqual(translated, "system-result")
        let customCalls = await customAPIClient.recordedCalls()
        let systemCalls = await systemClient.recordedCalls()
        XCTAssertTrue(customCalls.isEmpty)
        XCTAssertEqual(systemCalls, [.init(text: "你好", direction: .zhToEn)])
    }
}

private final class LocalTranslationClientMockURLProtocol: URLProtocol {
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
            fatalError("LocalTranslationClientMockURLProtocol.requestHandler was not set")
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

private final class RuntimeTranslationConfigSource: @unchecked Sendable {
    private let store: APISettingsStore

    init(store: APISettingsStore) {
        self.store = store
    }

    func load() -> AppConfig {
        AppConfig(settings: store.load())
    }
}

private func makeLocalTranslationClientMockedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [LocalTranslationClientMockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func requestBody(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer {
        stream.close()
    }

    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer {
        buffer.deallocate()
    }

    var data = Data()
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 {
            return nil
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }
    return data
}

private func XCTAssertLocalTranslationThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    expected: LocalTranslationClientError,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch let error as LocalTranslationClientError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}

private actor RecordingTranslationClient: TranslationClienting {
    struct Call: Equatable {
        let text: String
        let direction: TranslationDirection
    }

    private let result: String
    private var calls: [Call] = []

    init(result: String) {
        self.result = result
    }

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        calls.append(Call(text: text, direction: direction))
        return result
    }

    func recordedCalls() -> [Call] {
        calls
    }
}
