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
    private let onRefreshStatus: () -> Void
    private let onOpenBackendPanel: () -> Void
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
        onRefreshStatus: @escaping () -> Void = {},
        onOpenBackendPanel: @escaping () -> Void = {},
        onOpenShortcutPanel: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.permissionStatus = permissionStatus
        self.backendStatus = backendStatus
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
        self.onTranslateOCR = onTranslateOCR
        self.onRefreshStatus = onRefreshStatus
        self.onOpenBackendPanel = onOpenBackendPanel
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

    var refreshStatusLabel: String {
        L10n.refreshStatus
    }

    var keyboardShortcutsLabel: String {
        L10n.keyboardShortcuts
    }

    var backendPanelLabel: String {
        L10n.backendPanelMenuItem
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

    func refreshStatus() {
        onRefreshStatus()
    }

    func openBackendPanel() {
        onOpenBackendPanel()
    }

    func openKeyboardShortcuts() {
        onOpenShortcutPanel()
    }

    func quit() {
        onQuit()
    }
}
