import ApplicationServices

protocol AccessibilityPermissionChecking: Sendable {
    var isGranted: Bool { get }
}

struct AccessibilityPermission: AccessibilityPermissionChecking {
    var isGranted: Bool {
        AXIsProcessTrusted()
    }
}
