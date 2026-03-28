import SwiftUI

enum OverlayViewState: Equatable {
    case loading
    case result(String)
    case error(String)
}

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published private(set) var state: OverlayViewState = .loading

    private var closeAction: (() -> Void)?

    func bindCloseAction(_ action: @escaping () -> Void) {
        closeAction = action
    }

    func show(_ state: OverlayViewState) {
        self.state = state
    }

    func close() {
        closeAction?()
    }
}
