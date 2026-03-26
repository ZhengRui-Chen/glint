import XCTest
@testable import HYMTQuickTranslate

final class OverlayPresentationBehaviorTests: XCTestCase {
    func test_dismissal_policy_allows_click_away_after_grace_period() {
        let policy = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)
        XCTAssertTrue(policy.shouldCloseOnClickAway(shownAt: 1.0, now: 1.5))
    }

    func test_dismissal_policy_keeps_focus_loss_grace_period() {
        let policy = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)
        XCTAssertFalse(policy.shouldCloseOnFocusLoss(shownAt: 1.0, now: 1.1))
    }
}
