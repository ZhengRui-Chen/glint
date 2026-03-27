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
        statusMessage = "Press a shortcut. Esc cancels."
    }

    func cancelRecording() {
        recordingTarget = nil
        statusMessage = nil
    }

    func resetToDefaults() {
        shortcutSettings = .default
        recordingTarget = nil
        statusMessage = "Defaults restored"
    }

    private func shortcutLabel(for target: ShortcutTarget) -> String {
        let shortcut = switch target {
        case .clipboard:
            shortcutSettings.clipboardShortcut
        case .selection:
            shortcutSettings.selectionShortcut
        }

        return shortcut.displayName
    }
}
