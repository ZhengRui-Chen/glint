import XCTest
@testable import Glint

final class LocalTranslationClientTests: XCTestCase {
    func test_client_decodes_first_choice_content() throws {
        let data = """
        {"choices":[{"message":{"content":"很高兴见到你。"}}]}
        """.data(using: .utf8)!
        let decoded = try LocalTranslationClient.decodeContent(from: data)
        XCTAssertEqual(decoded, "很高兴见到你。")
    }
}
