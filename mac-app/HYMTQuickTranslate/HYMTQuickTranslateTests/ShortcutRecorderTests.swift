import Carbon.HIToolbox
import XCTest
@testable import HYMTQuickTranslate

final class ShortcutRecorderTests: XCTestCase {
    func test_recorder_persists_updated_shortcut_settings() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let recorder = ShortcutRecorder(
            existingSettings: .default,
            userDefaults: userDefaults
        )

        let result = recorder.save(newShortcut, for: .selection)
        let updatedSettings = try XCTUnwrap(try? result.get())

        XCTAssertEqual(updatedSettings.selectionShortcut, newShortcut)
        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), updatedSettings)
    }

    func test_recorder_rejects_duplicate_shortcuts() {
        let settings = ShortcutSettings.default
        let recorder = ShortcutRecorder(existingSettings: settings)
        let result = recorder.validate(settings.clipboardShortcut, for: .selection)

        XCTAssertEqual(result, .failure(.duplicateShortcut))
    }
}
