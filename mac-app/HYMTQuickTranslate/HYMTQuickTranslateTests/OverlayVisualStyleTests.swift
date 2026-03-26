import XCTest
@testable import HYMTQuickTranslate

final class OverlayVisualStyleTests: XCTestCase {
    func test_overlay_corner_radius_uses_single_shared_value() {
        XCTAssertEqual(OverlayVisualStyle.cornerRadius, 20)
    }

    func test_visual_style_uses_fallback_on_older_systems() {
        let style = OverlayVisualStyle.make(isMacOS26OrNewer: false)
        XCTAssertEqual(style, .fallback)
    }

    func test_visual_style_uses_liquid_glass_on_macos_26_or_newer() {
        let style = OverlayVisualStyle.make(isMacOS26OrNewer: true)
        XCTAssertEqual(style, .liquidGlass)
    }

    func test_liquid_glass_style_uses_clearer_layers_with_stronger_edge_definition() {
        XCTAssertLessThan(
            OverlayVisualStyle.liquidGlass.backgroundMaterialOpacity,
            OverlayVisualStyle.fallback.backgroundMaterialOpacity
        )
        XCTAssertLessThan(
            OverlayVisualStyle.liquidGlass.glassTintOpacity,
            OverlayVisualStyle.fallback.glassTintOpacity
        )
        XCTAssertLessThan(
            OverlayVisualStyle.liquidGlass.surfaceFillOpacity,
            OverlayVisualStyle.fallback.surfaceFillOpacity
        )
        XCTAssertGreaterThan(
            OverlayVisualStyle.liquidGlass.edgeHighlightOpacity,
            OverlayVisualStyle.fallback.edgeHighlightOpacity
        )
        XCTAssertTrue(OverlayVisualStyle.liquidGlass.prefersClearGlass)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.backgroundMaterialOpacity, 0.60, accuracy: 0.001)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.glassTintOpacity, 0.02, accuracy: 0.001)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.surfaceFillOpacity, 0.06, accuracy: 0.001)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.edgeHighlightOpacity, 0.24, accuracy: 0.001)
    }

    func test_liquid_glass_style_uses_sampled_readability_veil_without_local_content_card() {
        XCTAssertEqual(OverlayVisualStyle.fallback.contentSurfaceOpacity, 0.0, accuracy: 0.001)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.contentSurfaceOpacity, 0.0, accuracy: 0.001)
        XCTAssertEqual(OverlayVisualStyle.liquidGlass.contentBorderOpacity, 0.0, accuracy: 0.001)
        XCTAssertEqual(
            OverlayVisualStyle.liquidGlass.adaptiveReadabilityOpacity(for: nil),
            0.16,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            OverlayVisualStyle.liquidGlass.adaptiveReadabilityOpacity(for: 0.12),
            OverlayVisualStyle.liquidGlass.adaptiveReadabilityOpacity(for: 0.82)
        )
        XCTAssertEqual(
            OverlayVisualStyle.liquidGlass.adaptiveReadabilityOpacity(for: 0.12),
            0.27,
            accuracy: 0.01
        )
        XCTAssertEqual(
            OverlayVisualStyle.liquidGlass.adaptiveReadabilityOpacity(for: 0.82),
            0.08,
            accuracy: 0.01
        )
    }

    func test_liquid_glass_style_requires_transparent_window_host() {
        XCTAssertFalse(OverlayVisualStyle.fallback.requiresTransparentWindow)
        XCTAssertTrue(OverlayVisualStyle.liquidGlass.requiresTransparentWindow)
    }
}
