import XCTest
@testable import Glint

final class GlintTests: XCTestCase {
    func test_app_branding_uses_glint_display_name() {
        XCTAssertEqual(AppBranding.displayName, "Glint")
    }

    func test_app_config_defaults_to_empty_runtime_api_settings() {
        let config = AppConfig.default
        XCTAssertEqual(config.baseURLString, "")
        XCTAssertEqual(config.apiKey, "")
        XCTAssertEqual(config.model, "")
    }
}
