import Carbon.HIToolbox
import Foundation

enum ShortcutSettingsError: Error, Equatable {
    case duplicateShortcut
}

enum ShortcutTarget: Equatable {
    case clipboard
    case selection
}

struct ShortcutSettings: Equatable, Codable {
    let clipboardShortcut: GlobalHotkeyShortcut
    let selectionShortcut: GlobalHotkeyShortcut

    static let `default` = ShortcutSettings(
        clipboardShortcut: .default,
        selectionShortcut: .selectionDefault
    )

    private static let userDefaultsKey = "shortcutSettings"

    static func load(from userDefaults: UserDefaults = .standard) -> ShortcutSettings {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ShortcutSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(to userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func shortcut(for target: ShortcutTarget) -> GlobalHotkeyShortcut {
        switch target {
        case .clipboard:
            clipboardShortcut
        case .selection:
            selectionShortcut
        }
    }

    func replacing(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) -> Result<ShortcutSettings, ShortcutSettingsError> {
        let candidate: ShortcutSettings
        switch target {
        case .clipboard:
            candidate = ShortcutSettings(
                clipboardShortcut: shortcut,
                selectionShortcut: selectionShortcut
            )
        case .selection:
            candidate = ShortcutSettings(
                clipboardShortcut: clipboardShortcut,
                selectionShortcut: shortcut
            )
        }

        guard candidate.clipboardShortcut != candidate.selectionShortcut else {
            return .failure(.duplicateShortcut)
        }
        return .success(candidate)
    }
}

extension GlobalHotkeyShortcut: Codable, Equatable {
    static let selectionDefault = GlobalHotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            keyCode: try container.decode(UInt32.self, forKey: .keyCode),
            modifiers: try container.decode(UInt32.self, forKey: .modifiers)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
    }

    static func == (lhs: GlobalHotkeyShortcut, rhs: GlobalHotkeyShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}
