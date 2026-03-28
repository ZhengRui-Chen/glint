import XCTest
@testable import Glint

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

    func test_noninteractive_overlay_states_do_not_require_app_activation() {
        XCTAssertFalse(OverlayPanelController.shouldActivateApp(for: .loading))
        XCTAssertFalse(OverlayPanelController.shouldActivateApp(for: .result("done")))
        XCTAssertFalse(OverlayPanelController.shouldActivateApp(for: .error("failed")))
    }

    func test_confirmation_overlay_state_requires_app_activation() {
        XCTAssertTrue(OverlayPanelController.shouldActivateApp(for: .confirmLongText("long text")))
    }

    func test_overlay_content_relies_on_panel_animation_instead_of_internal_state_transition_animation() {
        XCTAssertFalse(OverlayContentView.usesAnimatedStateTransitions)
    }
}
