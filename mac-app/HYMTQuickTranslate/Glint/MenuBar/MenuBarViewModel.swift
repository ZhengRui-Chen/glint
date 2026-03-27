import Foundation

enum AccessibilityPermissionStatus: Equatable {
    case granted
    case required
}

struct MenuBarViewModel {
    let permissionStatus: AccessibilityPermissionStatus
    let backendStatus: BackendStatusSnapshot
    let shortcutSettings: ShortcutSettings
    let recordingTarget: ShortcutTarget?
    let shortcutStatusLabel: String?

    private let onTranslateSelection: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onTranslateOCR: () -> Void
    private let onStartService: () -> Void
    private let onStopService: () -> Void
    private let onRestartService: () -> Void
    private let onRefreshStatus: () -> Void
    private let onStartRecording: (ShortcutTarget) -> Void
    private let onCancelShortcutRecording: () -> Void
    private let onQuit: () -> Void

    init(
        permissionStatus: AccessibilityPermissionStatus,
        backendStatus: BackendStatusSnapshot = .available(
            detail: "Translation backend is reachable"
        ),
        shortcutSettings: ShortcutSettings = .default,
        recordingTarget: ShortcutTarget? = nil,
        shortcutStatusLabel: String? = nil,
        onTranslateSelection: @escaping () -> Void = {},
        onTranslateClipboard: @escaping () -> Void = {},
        onTranslateOCR: @escaping () -> Void = {},
        onStartService: @escaping () -> Void = {},
        onStopService: @escaping () -> Void = {},
        onRestartService: @escaping () -> Void = {},
        onRefreshStatus: @escaping () -> Void = {},
        onStartRecording: @escaping (ShortcutTarget) -> Void = { _ in },
        onCancelShortcutRecording: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.permissionStatus = permissionStatus
        self.backendStatus = backendStatus
        self.shortcutSettings = shortcutSettings
        self.recordingTarget = recordingTarget
        self.shortcutStatusLabel = shortcutStatusLabel
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
        self.onTranslateOCR = onTranslateOCR
        self.onStartService = onStartService
        self.onStopService = onStopService
        self.onRestartService = onRestartService
        self.onRefreshStatus = onRefreshStatus
        self.onStartRecording = onStartRecording
        self.onCancelShortcutRecording = onCancelShortcutRecording
        self.onQuit = onQuit
    }

    var backendHeadline: String {
        backendStatus.headline
    }

    var backendDetail: String {
        backendStatus.detail
    }

    var translateSelectionLabel: String {
        "Translate Selection"
    }

    var translateClipboardLabel: String {
        "Translate Clipboard"
    }

    var translateOCRLabel: String {
        "Translate OCR Area"
    }

    var startServiceLabel: String {
        "Start Service"
    }

    var stopServiceLabel: String {
        "Stop Service"
    }

    var restartServiceLabel: String {
        "Restart Service"
    }

    var refreshStatusLabel: String {
        "Refresh Status"
    }

    var canTranslateSelection: Bool {
        backendStatus.canTranslate
    }

    var canTranslateClipboard: Bool {
        backendStatus.canTranslate
    }

    var canTranslateOCR: Bool {
        backendStatus.canTranslate
    }

    var canStartService: Bool {
        backendStatus.canStartService
    }

    var canStopService: Bool {
        backendStatus.canStopService
    }

    var canRestartService: Bool {
        backendStatus.canRestartService
    }

    var canRefreshStatus: Bool {
        backendStatus.canRefreshStatus
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

    var ocrShortcutLabel: String {
        shortcutLabel(for: .ocr)
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

    func translateOCR() {
        onTranslateOCR()
    }

    func startService() {
        onStartService()
    }

    func stopService() {
        onStopService()
    }

    func restartService() {
        onRestartService()
    }

    func refreshStatus() {
        onRefreshStatus()
    }

    func startRecordingSelectionShortcut() {
        onStartRecording(.selection)
    }

    func startRecordingClipboardShortcut() {
        onStartRecording(.clipboard)
    }

    func startRecordingOCRShortcut() {
        onStartRecording(.ocr)
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
        case .ocr:
            "OCR"
        }

        if recordingTarget == target {
            return "\(title) Shortcut: Press new shortcut"
        }

        let shortcut = switch target {
        case .clipboard:
            shortcutSettings.clipboardShortcut
        case .selection:
            shortcutSettings.selectionShortcut
        case .ocr:
            shortcutSettings.ocrShortcut
        }
        return "\(title) Shortcut: \(shortcut.displayName)"
    }
}
