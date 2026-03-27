import AppKit
import Carbon.HIToolbox
import Foundation

enum ShortcutRecorderError: Error, Equatable {
    case duplicateShortcut
}

final class ShortcutRecorder {
    private(set) var settings: ShortcutSettings
    private let userDefaults: UserDefaults

    init(
        existingSettings: ShortcutSettings,
        userDefaults: UserDefaults = .standard
    ) {
        self.settings = existingSettings
        self.userDefaults = userDefaults
    }

    func validate(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) -> Result<ShortcutSettings, ShortcutRecorderError> {
        settings.replacing(shortcut, for: target).mapError { _ in
            .duplicateShortcut
        }
    }

    func save(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) -> Result<ShortcutSettings, ShortcutRecorderError> {
        let result = validate(shortcut, for: target)
        if case let .success(updatedSettings) = result {
            settings = updatedSettings
            updatedSettings.save(to: userDefaults)
        }
        return result
    }

    func resetToDefaults() -> ShortcutSettings {
        settings = .default
        settings.save(to: userDefaults)
        return settings
    }

    static func shortcut(from event: NSEvent) -> GlobalHotkeyShortcut? {
        guard event.type == .keyDown else {
            return nil
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            return nil
        }

        return GlobalHotkeyShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )
    }

    static func isCancelEvent(_ event: NSEvent) -> Bool {
        event.type == .keyDown && event.keyCode == UInt16(kVK_Escape)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }
}
