import Foundation

enum AccessibilityPermissionStatus: Equatable {
    case granted
    case required
}

struct MenuBarViewModel {
    let permissionStatus: AccessibilityPermissionStatus
    let backendStatus: BackendStatusSnapshot

    private let onTranslateSelection: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onStartService: () -> Void
    private let onStopService: () -> Void
    private let onRestartService: () -> Void
    private let onRefreshStatus: () -> Void
    private let onOpenShortcutPanel: () -> Void
    private let onQuit: () -> Void

    init(
        permissionStatus: AccessibilityPermissionStatus,
        backendStatus: BackendStatusSnapshot = .available(
            detail: "Translation backend is reachable"
        ),
        onTranslateSelection: @escaping () -> Void = {},
        onTranslateClipboard: @escaping () -> Void = {},
        onStartService: @escaping () -> Void = {},
        onStopService: @escaping () -> Void = {},
        onRestartService: @escaping () -> Void = {},
        onRefreshStatus: @escaping () -> Void = {},
        onOpenShortcutPanel: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.permissionStatus = permissionStatus
        self.backendStatus = backendStatus
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
        self.onStartService = onStartService
        self.onStopService = onStopService
        self.onRestartService = onRestartService
        self.onRefreshStatus = onRefreshStatus
        self.onOpenShortcutPanel = onOpenShortcutPanel
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

    var keyboardShortcutsLabel: String {
        "Keyboard Shortcuts…"
    }

    var canTranslateSelection: Bool {
        backendStatus.canTranslate
    }

    var canTranslateClipboard: Bool {
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

    var quitLabel: String {
        "Quit \(AppBranding.displayName)"
    }

    func translateSelection() {
        onTranslateSelection()
    }

    func translateClipboard() {
        onTranslateClipboard()
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

    func openKeyboardShortcuts() {
        onOpenShortcutPanel()
    }

    func quit() {
        onQuit()
    }
}
