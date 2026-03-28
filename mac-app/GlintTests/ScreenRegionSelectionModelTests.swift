import CoreGraphics
import XCTest
@testable import Glint

@MainActor
final class ScreenRegionSelectionModelTests: XCTestCase {
    func test_selection_rect_is_normalized_from_drag_points() {
        let model = ScreenRegionSelectionModel(minimumSelectionSize: 12)

        model.beginSelection(at: CGPoint(x: 120, y: 80))
        model.updateSelection(at: CGPoint(x: 40, y: 20))

        XCTAssertEqual(model.selectionRect, CGRect(x: 40, y: 20, width: 80, height: 60))
    }

    func test_finish_rejects_tiny_selection() {
        let model = ScreenRegionSelectionModel(minimumSelectionSize: 20)

        model.beginSelection(at: CGPoint(x: 10, y: 10))
        let result = model.finishSelection(at: CGPoint(x: 22, y: 24))

        XCTAssertNil(result)
        XCTAssertEqual(model.selectionRect, .zero)
    }

    func test_display_rect_flips_window_coordinates_into_swiftui_space() {
        let rect = ScreenRegionSelectionLayout.displayRect(
            for: CGRect(x: 40, y: 20, width: 80, height: 60),
            canvasHeight: 200
        )

        XCTAssertEqual(rect, CGRect(x: 40, y: 120, width: 80, height: 60))
    }

    func test_capture_rect_uses_quartz_global_display_coordinates() {
        let rect = ScreenRegionSelectionLayout.captureRect(
            for: CGRect(x: 40, y: 20, width: 80, height: 60),
            panelFrame: CGRect(x: 0, y: 0, width: 300, height: 200),
            desktopFrame: CGRect(x: 0, y: 0, width: 300, height: 200)
        )

        XCTAssertEqual(rect, CGRect(x: 40, y: 120, width: 80, height: 60))
    }

    func test_capture_rect_flips_against_entire_desktop_space_for_multidisplay_layouts() {
        let rect = ScreenRegionSelectionLayout.captureRect(
            for: CGRect(x: 40, y: 220, width: 80, height: 60),
            panelFrame: CGRect(x: 0, y: 0, width: 300, height: 400),
            desktopFrame: CGRect(x: 0, y: 0, width: 300, height: 400)
        )

        XCTAssertEqual(rect, CGRect(x: 40, y: 120, width: 80, height: 60))
    }

    func test_panel_frames_keep_each_display_separate_for_multimonitor_capture() {
        let frames = ScreenRegionSelectionLayout.panelFrames(
            for: [
                CGRect(x: 0, y: 0, width: 1512, height: 982),
                CGRect(x: 1512, y: 0, width: 1728, height: 1117),
            ]
        )

        XCTAssertEqual(
            frames,
            [
                CGRect(x: 0, y: 0, width: 1512, height: 982),
                CGRect(x: 1512, y: 0, width: 1728, height: 1117),
            ]
        )
    }

    func test_local_selection_rect_intersects_global_selection_with_screen_frame() {
        let rect = ScreenRegionSelectionLayout.localSelectionRect(
            for: CGRect(x: 1600, y: 100, width: 240, height: 120),
            screenFrame: CGRect(x: 1512, y: 0, width: 1728, height: 1117)
        )

        XCTAssertEqual(rect, CGRect(x: 88, y: 100, width: 240, height: 120))
    }

    func test_local_selection_rect_returns_zero_for_non_intersecting_screen() {
        let rect = ScreenRegionSelectionLayout.localSelectionRect(
            for: CGRect(x: 1600, y: 100, width: 240, height: 120),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )

        XCTAssertEqual(rect, CGRect.zero)
    }
}
