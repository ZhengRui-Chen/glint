import Foundation

@MainActor
final class ShortcutPanelViewModel {
    private(set) var shortcutSettings: ShortcutSettings
    private(set) var recordingTarget: ShortcutTarget?
    private(set) var statusMessage: String?

    init(shortcutSettings: ShortcutSettings) {
        self.shortcutSettings = shortcutSettings
    }

    var selectionShortcutLabel: String {
        shortcutLabel(for: .selection)
    }

    var clipboardShortcutLabel: String {
        shortcutLabel(for: .clipboard)
    }

    var isRecordingSelectionShortcut: Bool {
        recordingTarget == .selection
    }

    var isRecordingClipboardShortcut: Bool {
        recordingTarget == .clipboard
    }

    func startRecording(for target: ShortcutTarget) {
        recordingTarget = target
        statusMessage = "Press a new shortcut, or Esc to cancel"
    }

    func cancelRecording() {
        recordingTarget = nil
        statusMessage = nil
    }

    func applyRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) {
        guard let target = recordingTarget else {
            return
        }

        let recorder = ShortcutRecorder(existingSettings: shortcutSettings)
        switch recorder.validate(shortcut, for: target) {
        case let .success(updatedSettings):
            shortcutSettings = updatedSettings
            recordingTarget = nil
            statusMessage = "Shortcut saved"
        case .failure(.duplicateShortcut):
            statusMessage = "This shortcut is already used by Glint"
        }
    }

    func resetToDefaults() {
        shortcutSettings = .default
        recordingTarget = nil
        statusMessage = "Defaults restored"
    }

    private func shortcutLabel(for target: ShortcutTarget) -> String {
        let title = switch target {
        case .clipboard:
            "Clipboard"
        case .selection:
            "Selection"
        }

        let shortcut = switch target {
        case .clipboard:
            shortcutSettings.clipboardShortcut
        case .selection:
            shortcutSettings.selectionShortcut
        }

        return "\(title) Shortcut: \(shortcut.displayName)"
    }
}
