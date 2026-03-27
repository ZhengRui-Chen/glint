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
