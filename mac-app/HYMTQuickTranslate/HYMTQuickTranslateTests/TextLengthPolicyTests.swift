import XCTest
@testable import HYMTQuickTranslate

final class TextLengthPolicyTests: XCTestCase {
    func test_text_length_policy_requires_confirmation_above_soft_limit() {
        let policy = TextLengthPolicy(softLimit: 2000, hardLimit: 8000)
        XCTAssertEqual(
            policy.evaluate(String(repeating: "a", count: 2001)),
            .needsConfirmation
        )
    }
}
