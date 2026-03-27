import CoreGraphics

enum OverlayPlacement: Equatable {
    case centered
    case anchored(CGPoint)
}

struct OverlayPlacementResolver {
    func resolve(cursorAnchor: CGPoint?) -> OverlayPlacement {
        guard let cursorAnchor else {
            return .centered
        }
        return .anchored(cursorAnchor)
    }
}
