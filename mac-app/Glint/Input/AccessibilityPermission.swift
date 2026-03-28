import ApplicationServices

protocol AccessibilityPermissionChecking: Sendable {
    var isGranted: Bool { get }
    @discardableResult
    func requestAccessPrompt() -> Bool
}

struct AccessibilityPermission: AccessibilityPermissionChecking {
    var isGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccessPrompt() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
