import Foundation

enum AccessibilityPermissionStatus: Equatable {
    case granted
    case required
}

struct MenuBarViewModel {
    let permissionStatus: AccessibilityPermissionStatus
    let shortcutSettings: ShortcutSettings
    let recordingTarget: ShortcutTarget?
    let shortcutStatusLabel: String?

    private let onTranslateSelection: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onStartRecording: (ShortcutTarget) -> Void
    private let onCancelShortcutRecording: () -> Void
    private let onQuit: () -> Void

    init(
        permissionStatus: AccessibilityPermissionStatus,
        shortcutSettings: ShortcutSettings = .default,
        recordingTarget: ShortcutTarget? = nil,
        shortcutStatusLabel: String? = nil,
        onTranslateSelection: @escaping () -> Void = {},
        onTranslateClipboard: @escaping () -> Void = {},
        onStartRecording: @escaping (ShortcutTarget) -> Void = { _ in },
        onCancelShortcutRecording: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.permissionStatus = permissionStatus
        self.shortcutSettings = shortcutSettings
        self.recordingTarget = recordingTarget
        self.shortcutStatusLabel = shortcutStatusLabel
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
        self.onStartRecording = onStartRecording
        self.onCancelShortcutRecording = onCancelShortcutRecording
        self.onQuit = onQuit
    }

    var translateSelectionLabel: String {
        "Translate Selection"
    }

    var translateClipboardLabel: String {
        "Translate Clipboard"
    }

    var permissionLabel: String {
        let statusText = switch permissionStatus {
        case .granted:
            "Granted"
        case .required:
            "Required"
        }
        return "Accessibility Permission: \(statusText)"
    }

    var selectionShortcutLabel: String {
        shortcutLabel(for: .selection)
    }

    var clipboardShortcutLabel: String {
        shortcutLabel(for: .clipboard)
    }

    var cancelShortcutRecordingLabel: String {
        "Cancel Shortcut Recording"
    }

    var quitLabel: String {
        "Quit \(AppBranding.displayName)"
    }

    func translateSelection() {
        onTranslateSelection()
    }

    func translateClipboard() {
        onTranslateClipboard()
    }

    func startRecordingSelectionShortcut() {
        onStartRecording(.selection)
    }

    func startRecordingClipboardShortcut() {
        onStartRecording(.clipboard)
    }

    func cancelShortcutRecording() {
        onCancelShortcutRecording()
    }

    func quit() {
        onQuit()
    }

    private func shortcutLabel(for target: ShortcutTarget) -> String {
        let title = switch target {
        case .clipboard:
            "Clipboard"
        case .selection:
            "Selection"
        }

        if recordingTarget == target {
            return "\(title) Shortcut: Press new shortcut"
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
