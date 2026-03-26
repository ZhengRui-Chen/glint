import XCTest
@testable import HYMTQuickTranslate

final class HYMTQuickTranslateTests: XCTestCase {
    func test_app_branding_uses_glint_display_name() {
        XCTAssertEqual(AppBranding.displayName, "Glint")
    }

    func test_app_config_uses_local_service_defaults() {
        let config = AppConfig.default
        XCTAssertEqual(config.baseURL.absoluteString, "http://127.0.0.1:8001")
        XCTAssertEqual(config.model, "HY-MT1.5-1.8B-4bit")
    }
}
