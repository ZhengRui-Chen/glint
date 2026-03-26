import Foundation

enum AccessibilityPermissionStatus: Equatable {
    case granted
    case required
}

struct MenuBarViewModel {
    let permissionStatus: AccessibilityPermissionStatus

    private let onTranslateSelection: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onQuit: () -> Void

    init(
        permissionStatus: AccessibilityPermissionStatus,
        onTranslateSelection: @escaping () -> Void = {},
        onTranslateClipboard: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.permissionStatus = permissionStatus
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
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

    var quitLabel: String {
        "Quit HYMT Quick Translate"
    }

    func translateSelection() {
        onTranslateSelection()
    }

    func translateClipboard() {
        onTranslateClipboard()
    }

    func quit() {
        onQuit()
    }
}
