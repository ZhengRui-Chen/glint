import Foundation

protocol TextInputSource: Sendable {
    func resolveText() async -> Result<String, TextInputFailure>
}

enum TextInputSourceError: Error, Equatable {
    case noText
    case permissionRequired
    case automationPermissionRequired
    case unsupportedHostApp
    case ocrUnavailable
}

struct TextInputFailure: Error, Equatable {
    let error: TextInputSourceError
    let diagnostics: String?

    init(_ error: TextInputSourceError, diagnostics: String? = nil) {
        self.error = error
        self.diagnostics = diagnostics
    }
}
