import XCTest
@testable import HYMTQuickTranslate

final class OverlayDismissalPolicyTests: XCTestCase {
    func test_policy_keeps_panel_open_for_immediate_focus_loss() {
        let policy = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)
        let shownAt: TimeInterval = 10

        XCTAssertFalse(
            policy.shouldCloseOnFocusLoss(
                shownAt: shownAt,
                now: shownAt + 0.05
            )
        )
    }

    func test_policy_allows_focus_loss_after_grace_period() {
        let policy = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)
        let shownAt: TimeInterval = 10

        XCTAssertTrue(
            policy.shouldCloseOnFocusLoss(
                shownAt: shownAt,
                now: shownAt + 0.5
            )
        )
    }
}
