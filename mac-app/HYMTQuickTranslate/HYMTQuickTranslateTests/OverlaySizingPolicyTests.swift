import XCTest
@testable import HYMTQuickTranslate

final class OverlaySizingPolicyTests: XCTestCase {
    func test_sizing_policy_uses_compact_height_for_short_result() {
        let policy = OverlaySizingPolicy(minHeight: 180, maxHeight: 420)
        let height = policy.height(for: "Hello")
        XCTAssertEqual(height, 180)
    }

    func test_sizing_policy_grows_for_multiple_lines() {
        let policy = OverlaySizingPolicy(minHeight: 180, maxHeight: 420)
        let height = policy.height(for: "Line 1\nLine 2\nLine 3\nLine 4")
        XCTAssertEqual(height, 264)
    }

    func test_sizing_policy_clamps_to_maximum_height() {
        let policy = OverlaySizingPolicy(minHeight: 180, maxHeight: 420)
        let height = policy.height(for: String(repeating: "Long text ", count: 80))
        XCTAssertEqual(height, 420)
    }
}
