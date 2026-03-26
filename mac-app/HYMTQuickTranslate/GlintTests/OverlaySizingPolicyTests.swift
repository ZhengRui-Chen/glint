import XCTest
@testable import Glint

final class OverlaySizingPolicyTests: XCTestCase {
    func test_sizing_policy_uses_compact_height_for_short_result() {
        let policy = OverlaySizingPolicy(minHeight: 144, maxHeight: 420)
        let height = policy.height(for: "Hello")
        XCTAssertEqual(height, 144)
    }

    func test_sizing_policy_grows_for_multiple_lines() {
        let policy = OverlaySizingPolicy(minHeight: 144, maxHeight: 420)
        let height = policy.height(for: "Line 1\nLine 2\nLine 3\nLine 4")
        XCTAssertEqual(height, 228)
    }

    func test_sizing_policy_clamps_to_maximum_height() {
        let policy = OverlaySizingPolicy(minHeight: 144, maxHeight: 420)
        let height = policy.height(for: String(repeating: "Long text ", count: 80))
        XCTAssertEqual(height, 420)
    }

    func test_default_policy_preserves_safe_minimum_height_for_short_content() {
        XCTAssertEqual(OverlaySizingPolicy.default.minHeight, 180)
        XCTAssertEqual(OverlaySizingPolicy.default.height(for: "Hello"), 180)
    }
}
