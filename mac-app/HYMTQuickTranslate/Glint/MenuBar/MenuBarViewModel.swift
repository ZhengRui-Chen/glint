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
    private let onTranslateOCR: () -> Void
    private let onStartService: () -> Void
    private let onStopService: () -> Void
    private let onRestartService: () -> Void
    private let onRefreshStatus: () -> Void
    private let onOpenShortcutPanel: () -> Void
    private let onQuit: () -> Void

    init(
        permissionStatus: AccessibilityPermissionStatus,
        backendStatus: BackendStatusSnapshot = .available(
            detail: L10n.backendReachable
        ),
        onTranslateSelection: @escaping () -> Void = {},
        onTranslateClipboard: @escaping () -> Void = {},
        onTranslateOCR: @escaping () -> Void = {},
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
        self.onTranslateOCR = onTranslateOCR
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
        L10n.translateSelection
    }

    var translateClipboardLabel: String {
        L10n.translateClipboard
    }

    var translateOCRLabel: String {
        L10n.translateOCRArea
    }

    var startServiceLabel: String {
        L10n.startService
    }

    var stopServiceLabel: String {
        L10n.stopService
    }

    var restartServiceLabel: String {
        L10n.restartService
    }

    var refreshStatusLabel: String {
        L10n.refreshStatus
    }

    var keyboardShortcutsLabel: String {
        L10n.keyboardShortcuts
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
            L10n.accessibilityPermissionGranted
        case .required:
            L10n.accessibilityPermissionRequired
        }
        return L10n.accessibilityPermission(status: statusText)
    }

    var quitLabel: String {
        L10n.quitApp(appName: AppBranding.displayName)
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

    func openKeyboardShortcuts() {
        onOpenShortcutPanel()
    }

    func quit() {
        onQuit()
    }
}
