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
        "Control + Option + Command + T"
    }
}

final class GlobalHotkeyMonitor {
    private static let signature = OSType(0x48594D54)

    private let shortcut: GlobalHotkeyShortcut
    private let onTrigger: () -> Void
    private let identifier: UInt32

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    init(
        shortcut: GlobalHotkeyShortcut = .default,
        onTrigger: @escaping () -> Void
    ) {
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        self.identifier = 1
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

        var hotKeyID = EventHotKeyID(
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
