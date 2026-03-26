import AppKit
import Carbon.HIToolbox
import XCTest
@testable import HYMTQuickTranslate

final class ShortcutRecorderTests: XCTestCase {
    @MainActor
    func test_app_delegate_does_not_register_selection_hotkey_before_task6() {
        let appDelegate = AppDelegate()

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        XCTAssertNotNil(reflectedValue(named: "clipboardHotkeyMonitor", from: appDelegate))
        XCTAssertNil(reflectedValue(named: "selectionHotkeyMonitor", from: appDelegate))
    }

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

    func test_shortcut_from_rejects_bare_key_presses() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "t",
                charactersIgnoringModifiers: "t",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_T)
            )
        )

        XCTAssertNil(ShortcutRecorder.shortcut(from: event))
    }
}

private func reflectedValue(named label: String, from appDelegate: AppDelegate) -> Any? {
    Mirror(reflecting: appDelegate).children
        .first { $0.label == label }?
        .value
}
