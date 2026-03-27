import CoreGraphics
import SwiftUI

@MainActor
final class ScreenRegionSelectionModel: ObservableObject {
    @Published private(set) var selectionRect: CGRect = .zero

    let minimumSelectionSize: CGFloat
    private var startPoint: CGPoint?

    init(minimumSelectionSize: CGFloat = 18) {
        self.minimumSelectionSize = minimumSelectionSize
    }

    func beginSelection(at point: CGPoint) {
        startPoint = point
        selectionRect = CGRect(origin: point, size: .zero)
    }

    func updateSelection(at point: CGPoint) {
        guard let startPoint else {
            return
        }
        selectionRect = Self.normalizedRect(from: startPoint, to: point)
    }

    func finishSelection(at point: CGPoint) -> CGRect? {
        guard startPoint != nil else {
            return nil
        }

        updateSelection(at: point)
        defer {
            startPoint = nil
        }

        guard selectionRect.width >= minimumSelectionSize,
              selectionRect.height >= minimumSelectionSize else {
            selectionRect = .zero
            return nil
        }
        return selectionRect
    }

    func cancelSelection() {
        startPoint = nil
        selectionRect = .zero
    }

    private static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}
