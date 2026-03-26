import Foundation

struct OverlayDismissalPolicy: Equatable {
    let minimumFocusLossDelay: TimeInterval

    static let `default` = OverlayDismissalPolicy(minimumFocusLossDelay: 0.3)

    func shouldCloseOnFocusLoss(
        shownAt: TimeInterval,
        now: TimeInterval
    ) -> Bool {
        now - shownAt >= minimumFocusLossDelay
    }
}
