import Carbon.HIToolbox
import Foundation

struct GlobalHotkeyShortcut {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = GlobalHotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    var displayName: String {
        let modifierNames: [(UInt32, String)] = [
            (UInt32(controlKey), "Control"),
            (UInt32(optionKey), "Option"),
            (UInt32(shiftKey), "Shift"),
            (UInt32(cmdKey), "Command"),
        ]
        let parts = modifierNames
            .filter { modifiers & $0.0 != 0 }
            .map(\.1)

        let keyName = Self.keyName(for: keyCode)
        if parts.isEmpty {
            return keyName
        }
        return (parts + [keyName]).joined(separator: " + ")
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        default:
            return "KeyCode \(keyCode)"
        }
    }
}

final class GlobalHotkeyMonitor {
    private static let signature = OSType(0x48594D54)

    private var shortcut: GlobalHotkeyShortcut
    private let onTrigger: () -> Void
    private let identifier: UInt32

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    init(
        identifier: UInt32 = 1,
        shortcut: GlobalHotkeyShortcut = .default,
        onTrigger: @escaping () -> Void
    ) {
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        self.identifier = identifier
    }

    func start() {
        guard hotKeyRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else {
                    return noErr
                }
                let monitor = Unmanaged<GlobalHotkeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return monitor.handle(eventRef)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: identifier
        )
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    func invokeForTesting() {
        onTrigger()
    }

    func reload(shortcut: GlobalHotkeyShortcut) {
        let wasRunning = hotKeyRef != nil || eventHandler != nil
        stop()
        self.shortcut = shortcut
        if wasRunning {
            start()
        }
    }

    deinit {
        stop()
    }

    private func handle(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == identifier else {
            return noErr
        }

        onTrigger()
        return noErr
    }
}
