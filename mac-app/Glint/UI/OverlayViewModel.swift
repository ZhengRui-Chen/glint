import SwiftUI

enum OverlayViewState: Equatable {
    case loading
    case confirmLongText(String)
    case result(String)
    case error(String)
}

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published private(set) var state: OverlayViewState = .loading

    private var confirmAction: ((String) -> Void)?
    private var closeAction: (() -> Void)?

    func bindCloseAction(_ action: @escaping () -> Void) {
        closeAction = action
    }

    func show(_ state: OverlayViewState, onConfirm: ((String) -> Void)? = nil) {
        self.state = state
        confirmAction = onConfirm
    }

    func confirmLongText() {
        guard case let .confirmLongText(text) = state else {
            return
        }
        confirmAction?(text)
    }

    func close() {
        closeAction?()
    }
}
