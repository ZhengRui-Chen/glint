import AppKit
import ApplicationServices
import Foundation

enum SelectionProviderError: Error, Equatable {
    case noText
    case unsupportedHostApp
}

protocol SelectionProviding: Sendable {
    func selectedText() async -> Result<String, SelectionProviderError>
}

struct SelectionInputSource: TextInputSource {
    let permission: any AccessibilityPermissionChecking
    let provider: any SelectionProviding

    init(
        permission: any AccessibilityPermissionChecking = AccessibilityPermission(),
        provider: any SelectionProviding = AccessibilitySelectionProvider()
    ) {
        self.permission = permission
        self.provider = provider
    }

    func resolveText() async -> Result<String, TextInputSourceError> {
        guard permission.isGranted else {
            return .failure(.permissionRequired)
        }

        switch await provider.selectedText() {
        case let .success(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(.noText)
            }
            return .success(trimmed)
        case .failure(.noText):
            return .failure(.noText)
        case .failure(.unsupportedHostApp):
            return .failure(.unsupportedHostApp)
        }
    }
}

struct AccessibilitySelectionProvider: SelectionProviding {
    func selectedText() async -> Result<String, SelectionProviderError> {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return .failure(.unsupportedHostApp)
        }

        let applicationElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        guard let focusedElement = focusedElement(in: applicationElement)
                ?? focusedElement(in: AXUIElementCreateSystemWide()) else {
            return .failure(.unsupportedHostApp)
        }

        return selectedText(from: focusedElement)
    }

    private func focusedElement(in element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard error == .success else {
            return nil
        }

        return value as! AXUIElement?
    }

    private func selectedText(from element: AXUIElement) -> Result<String, SelectionProviderError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )

        switch error {
        case .success:
            if let text = value as? String {
                return .success(text)
            }
            return .failure(.noText)
        case .noValue:
            return .failure(.noText)
        case .attributeUnsupported:
            return .failure(.unsupportedHostApp)
        default:
            return .failure(.unsupportedHostApp)
        }
    }
}
