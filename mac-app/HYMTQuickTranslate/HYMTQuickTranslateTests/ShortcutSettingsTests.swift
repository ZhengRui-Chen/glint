import XCTest
@testable import HYMTQuickTranslate

final class ShortcutSettingsTests: XCTestCase {
    func test_settings_use_distinct_default_shortcuts() {
        let settings = ShortcutSettings.default
        XCTAssertNotEqual(settings.clipboardShortcut, settings.selectionShortcut)
    }

    func test_default_shortcuts_use_distinct_display_names() {
        XCTAssertEqual(GlobalHotkeyShortcut.default.displayName, "Control + Option + Command + T")
        XCTAssertEqual(GlobalHotkeyShortcut.selectionDefault.displayName, "Control + Option + Command + S")
    }

    func test_save_and_load_round_trip() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let settings = ShortcutSettings.default
        settings.save(to: userDefaults)

        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), settings)
    }

    func test_replacing_rejects_duplicate_shortcuts() {
        let settings = ShortcutSettings.default

        XCTAssertEqual(
            settings.replacing(settings.clipboardShortcut, for: .selection),
            .failure(.duplicateShortcut)
        )
    }
}
