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
        let applicationFocus = focusedElementLookup(in: applicationElement)
        if case let .found(element) = applicationFocus {
            return selectedText(from: element)
        }

        let systemFocus = focusedElementLookup(in: AXUIElementCreateSystemWide())
        if case let .found(element) = systemFocus {
            return selectedText(from: element)
        }

        if case .unsupportedHostApp = applicationFocus,
           case .unsupportedHostApp = systemFocus {
            return .failure(.unsupportedHostApp)
        }

        return .failure(.noText)
    }

    private func focusedElementLookup(in element: AXUIElement) -> FocusedElementLookup {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        return Self.focusedElementLookup(from: value, error: error)
    }

    private func selectedText(from element: AXUIElement) -> Result<String, SelectionProviderError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )

        return Self.selectionResult(from: value, error: error)
    }

    static func focusedElementLookup(from value: CFTypeRef?, error: AXError) -> FocusedElementLookup {
        switch error {
        case .success:
            guard let value else {
                return .unavailable
            }

            guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return .unavailable
            }

            return .found(unsafeDowncast(value, to: AXUIElement.self))
        case .attributeUnsupported:
            return .unsupportedHostApp
        default:
            return .unavailable
        }
    }

    static func selectionResult(from value: CFTypeRef?, error: AXError) -> Result<String, SelectionProviderError> {
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
            return .failure(.noText)
        }
    }
}

enum FocusedElementLookup {
    case found(AXUIElement)
    case unavailable
    case unsupportedHostApp
}
