import XCTest
@testable import HYMTQuickTranslate

final class OverlayVisualStyleTests: XCTestCase {
    func test_visual_style_uses_fallback_on_older_systems() {
        let style = OverlayVisualStyle.make(isMacOS26OrNewer: false)
        XCTAssertEqual(style, .fallback)
    }

    func test_visual_style_uses_liquid_glass_on_macos_26_or_newer() {
        let style = OverlayVisualStyle.make(isMacOS26OrNewer: true)
        XCTAssertEqual(style, .liquidGlass)
    }
}
