import Foundation

protocol TextInputSource: Sendable {
    func resolveText() async -> Result<String, TextInputSourceError>
}

enum TextInputSourceError: Error, Equatable {
    case noText
    case permissionRequired
    case unsupportedHostApp
}
