import Foundation

@MainActor
final class ShortcutPanelViewModel {
    private(set) var shortcutSettings: ShortcutSettings
    private(set) var recordingTarget: ShortcutTarget?
    private(set) var statusMessage: String?
    private var previewShortcut: GlobalHotkeyShortcut?
    private var previewModifiers: UInt32 = 0

    init(shortcutSettings: ShortcutSettings) {
        self.shortcutSettings = shortcutSettings
    }

    var selectionShortcutLabel: String {
        shortcutLabel(for: .selection)
    }

    var clipboardShortcutLabel: String {
        shortcutLabel(for: .clipboard)
    }

    var ocrShortcutLabel: String {
        shortcutLabel(for: .ocr)
    }

    var isRecordingSelectionShortcut: Bool {
        recordingTarget == .selection
    }

    var isRecordingClipboardShortcut: Bool {
        recordingTarget == .clipboard
    }

    func startRecording(for target: ShortcutTarget) {
        recordingTarget = target
        previewShortcut = nil
        previewModifiers = 0
        statusMessage = "Press a shortcut. Esc cancels."
    }

    func cancelRecording() {
        recordingTarget = nil
        previewShortcut = nil
        previewModifiers = 0
        statusMessage = nil
    }

    func previewModifierInput(_ modifiers: UInt32) {
        guard recordingTarget != nil else {
            return
        }
        previewShortcut = nil
        previewModifiers = modifiers
    }

    func previewRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) {
        guard recordingTarget != nil else {
            return
        }
        previewShortcut = shortcut
        previewModifiers = shortcut.modifiers
    }

    func resetToDefaults() {
        shortcutSettings = .default
        recordingTarget = nil
        previewShortcut = nil
        previewModifiers = 0
        statusMessage = "Defaults restored"
    }

    private func shortcutLabel(for target: ShortcutTarget) -> String {
        if recordingTarget == target {
            if let previewShortcut {
                return previewShortcut.displayName
            }
            let modifierPreview = GlobalHotkeyShortcut.displayString(
                modifiers: previewModifiers,
                keyCode: nil
            )
            if modifierPreview.isEmpty == false {
                return modifierPreview
            }
        }

        let shortcut = switch target {
        case .clipboard:
            shortcutSettings.clipboardShortcut
        case .selection:
            shortcutSettings.selectionShortcut
        case .ocr:
            shortcutSettings.ocrShortcut
        }

        return shortcut.displayName
    }
}
