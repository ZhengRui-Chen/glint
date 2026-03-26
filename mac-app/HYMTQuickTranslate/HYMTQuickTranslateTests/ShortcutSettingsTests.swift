import XCTest
@testable import HYMTQuickTranslate

final class ShortcutSettingsTests: XCTestCase {
    func test_settings_use_distinct_default_shortcuts() {
        let settings = ShortcutSettings.default
        XCTAssertNotEqual(settings.clipboardShortcut, settings.selectionShortcut)
    }
}
