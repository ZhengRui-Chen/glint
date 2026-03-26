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

    func test_dismiss_transition_fades_out_and_moves_down() {
        let transition = OverlayPanelTransition.dismiss(offset: 12)
        let frame = CGRect(x: 100, y: 200, width: 460, height: 220)
        let animatedFrame = transition.frame(fromVisibleFrame: frame)

        XCTAssertEqual(transition.duration, 0.18, accuracy: 0.001)
        XCTAssertEqual(transition.initialAlpha, 1, accuracy: 0.001)
        XCTAssertEqual(transition.finalAlpha, 0, accuracy: 0.001)
        XCTAssertGreaterThan(animatedFrame.minY, frame.minY)
        XCTAssertLessThan(animatedFrame.width, frame.width)
    }
}
