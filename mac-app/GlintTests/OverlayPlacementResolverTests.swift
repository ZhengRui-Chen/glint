import XCTest
@testable import Glint

final class OverlayPlacementResolverTests: XCTestCase {
    func test_resolver_falls_back_to_center_when_cursor_anchor_is_unavailable() {
        let resolver = OverlayPlacementResolver()
        let placement = resolver.resolve(cursorAnchor: nil)

        XCTAssertEqual(placement, .centered)
    }

    func test_resolver_anchors_overlay_when_cursor_anchor_exists() {
        let resolver = OverlayPlacementResolver()
        let anchor = CGPoint(x: 320, y: 240)

        let placement = resolver.resolve(cursorAnchor: anchor)

        XCTAssertEqual(placement, .anchored(anchor))
    }
}
