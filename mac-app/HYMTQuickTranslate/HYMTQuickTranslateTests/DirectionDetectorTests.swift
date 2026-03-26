import XCTest
@testable import HYMTQuickTranslate

final class DirectionDetectorTests: XCTestCase {
    func test_direction_detector_prefers_en2zh_for_latin_text() {
        XCTAssertEqual(DirectionDetector.detect("Hello world"), .enToZh)
    }

    func test_direction_detector_prefers_zh2en_for_han_text() {
        XCTAssertEqual(DirectionDetector.detect("你好，世界"), .zhToEn)
    }

    func test_direction_detector_falls_back_to_en2zh_for_weak_signal() {
        XCTAssertEqual(DirectionDetector.detect("https://example.com"), .enToZh)
    }
}
