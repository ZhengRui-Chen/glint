import AppKit
import ApplicationServices
import Foundation

enum SelectionProviderError: Error, Equatable {
    case noText
    case automationPermissionRequired
    case unsupportedHostApp
}

struct SelectionProviderFailure: Error, Equatable {
    let error: SelectionProviderError
    let diagnostics: String?

    init(_ error: SelectionProviderError, diagnostics: String? = nil) {
        self.error = error
        self.diagnostics = diagnostics
    }
}

struct SelectionTarget: Sendable, Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

protocol SelectionProviding: Sendable {
    func selectedText(for target: SelectionTarget?) async -> Result<String, SelectionProviderFailure>
}

protocol SelectionTargetProviding: Sendable {
    func currentTarget() -> SelectionTarget?
}

protocol FrontmostAppProviding: Sendable {
    func frontmostBundleIdentifier() -> String?
}

protocol BrowserSelectionProviding: Sendable {
    func selectedText(for bundleIdentifier: String) async -> Result<String, SelectionProviderFailure>
}

struct SelectionInputSource: TextInputSource {
    let permission: any AccessibilityPermissionChecking
    let targetProvider: any SelectionTargetProviding
    let provider: any SelectionProviding

    init(
        permission: any AccessibilityPermissionChecking = AccessibilityPermission(),
        targetProvider: any SelectionTargetProviding = FrontmostAppProvider(),
        provider: any SelectionProviding = BrowserFallbackSelectionProvider()
    ) {
        self.permission = permission
        self.targetProvider = targetProvider
        self.provider = provider
    }

    func resolveText() async -> Result<String, TextInputFailure> {
        guard permission.isGranted else {
            _ = permission.requestAccessPrompt()
            return .failure(TextInputFailure(.permissionRequired))
        }

        let target = targetProvider.currentTarget()
        switch await provider.selectedText(for: target) {
        case let .success(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(TextInputFailure(.noText))
            }
            return .success(trimmed)
        case let .failure(failure):
            return .failure(
                TextInputFailure(
                    mappedTextInputError(from: failure.error),
                    diagnostics: failure.diagnostics
                )
            )
        }
    }

    private func mappedTextInputError(from error: SelectionProviderError) -> TextInputSourceError {
        switch error {
        case .noText:
            .noText
        case .automationPermissionRequired:
            .automationPermissionRequired
        case .unsupportedHostApp:
            .unsupportedHostApp
        }
    }
}

struct FrontmostAppProvider: FrontmostAppProviding {
    func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

extension FrontmostAppProvider: SelectionTargetProviding {
    func currentTarget() -> SelectionTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return SelectionTarget(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier
        )
    }
}

struct BrowserFallbackSelectionProvider: SelectionProviding {
    let accessibilityProvider: any SelectionProviding
    let frontmostAppProvider: any FrontmostAppProviding
    let browserSelectionProvider: any BrowserSelectionProviding

    init(
        accessibilityProvider: any SelectionProviding = AccessibilitySelectionProvider(),
        frontmostAppProvider: any FrontmostAppProviding = FrontmostAppProvider(),
        browserSelectionProvider: any BrowserSelectionProviding = BrowserAppleScriptSelectionProvider()
    ) {
        self.accessibilityProvider = accessibilityProvider
        self.frontmostAppProvider = frontmostAppProvider
        self.browserSelectionProvider = browserSelectionProvider
    }

    func selectedText(for target: SelectionTarget?) async -> Result<String, SelectionProviderFailure> {
        let accessibilityResult = normalizedSelectionResult(
            await accessibilityProvider.selectedText(for: target)
        )
        switch accessibilityResult {
        case .success:
            return accessibilityResult
        case let .failure(accessibilityFailure):
            let accessibilityError = accessibilityFailure.error
            guard shouldTryBrowserFallback(for: accessibilityError) else {
                return .failure(accessibilityFailure)
            }

            guard let bundleIdentifier = target?.bundleIdentifier ?? frontmostAppProvider.frontmostBundleIdentifier() else {
                return .failure(
                    SelectionProviderFailure(
                        accessibilityError,
                        diagnostics: diagnosticsDescription(
                            frontmostApp: "<unknown>",
                            accessibilityError: accessibilityError,
                            browserFallback: "skipped:noFrontmostApp",
                            additionalDiagnostics: accessibilityFailure.diagnostics
                        )
                    )
                )
            }

            guard BrowserAppleScriptSelectionProvider.supports(bundleIdentifier: bundleIdentifier) else {
                return .failure(
                    SelectionProviderFailure(
                        accessibilityError,
                        diagnostics: diagnosticsDescription(
                            frontmostApp: bundleIdentifier,
                            accessibilityError: accessibilityError,
                            browserFallback: "skipped:unsupportedBrowser",
                            additionalDiagnostics: accessibilityFailure.diagnostics
                        )
                    )
                )
            }

            let browserResult = normalizedSelectionResult(
                await browserSelectionProvider.selectedText(for: bundleIdentifier)
            )
            switch browserResult {
            case .success:
                return browserResult
            case let .failure(browserFailure):
                let finalError = browserFailure.error == .automationPermissionRequired
                    ? SelectionProviderError.automationPermissionRequired
                    : accessibilityError
                return .failure(
                    SelectionProviderFailure(
                        finalError,
                        diagnostics: diagnosticsDescription(
                            frontmostApp: bundleIdentifier,
                            accessibilityError: accessibilityError,
                            browserFallback: "failed:\(browserFailure.error.diagnosticLabel)",
                            additionalDiagnostics: mergedDiagnostics(
                                accessibilityFailure.diagnostics,
                                browserFailure.diagnostics
                            )
                        )
                    )
                )
            }
        }
    }

    private func normalizedSelectionResult(
        _ result: Result<String, SelectionProviderFailure>
    ) -> Result<String, SelectionProviderFailure> {
        switch result {
        case let .success(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .failure(SelectionProviderFailure(.noText))
                : result
        case .failure:
            return result
        }
    }

    private func shouldTryBrowserFallback(for error: SelectionProviderError) -> Bool {
        switch error {
        case .noText, .unsupportedHostApp:
            true
        case .automationPermissionRequired:
            false
        }
    }

    private func diagnosticsDescription(
        frontmostApp: String,
        accessibilityError: SelectionProviderError,
        browserFallback: String,
        additionalDiagnostics: String?
    ) -> String {
        mergedDiagnostics(
            "frontmostApp=\(frontmostApp)",
            "accessibility=\(accessibilityError.diagnosticLabel)",
            "browserFallback=\(browserFallback)",
            additionalDiagnostics
        ) ?? ""
    }

    private func mergedDiagnostics(_ components: String?...) -> String? {
        let sanitized = components.compactMap { value -> String? in
            guard let value else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        guard !sanitized.isEmpty else {
            return nil
        }

        return sanitized.joined(separator: " | ")
    }
}

private extension SelectionProviderError {
    var diagnosticLabel: String {
        switch self {
        case .noText:
            "noText"
        case .automationPermissionRequired:
            "automationPermissionRequired"
        case .unsupportedHostApp:
            "unsupportedHostApp"
        }
    }
}

struct BrowserAppleScriptSelectionProvider: BrowserSelectionProviding {
    static let safariBundleIdentifier = "com.apple.Safari"
    static let chromeBundleIdentifier = "com.google.Chrome"

    private static let chromeKernelBrowserBundleIdentifiers: Set<String> = [
        chromeBundleIdentifier,
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser",
    ]

    static func supports(bundleIdentifier: String) -> Bool {
        bundleIdentifier == safariBundleIdentifier
            || chromeKernelBrowserBundleIdentifiers.contains(bundleIdentifier)
    }

    func selectedText(for bundleIdentifier: String) async -> Result<String, SelectionProviderFailure> {
        guard Self.supports(bundleIdentifier: bundleIdentifier) else {
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        }

        return await Task.detached(priority: .userInitiated) {
            let scriptSource = script(for: bundleIdentifier)
            var error: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource) else {
                return .failure(SelectionProviderFailure(.unsupportedHostApp))
            }

            let descriptor = script.executeAndReturnError(&error)
            if let error {
                return mapAppleScriptError(error)
            }

            guard let text = descriptor.stringValue else {
                return .failure(SelectionProviderFailure(.noText))
            }

            return .success(text)
        }.value
    }

    private func script(for bundleIdentifier: String) -> String {
        if bundleIdentifier == Self.safariBundleIdentifier {
            return """
            tell application id "\(bundleIdentifier)"
                tell front window
                    set selection_text to do JavaScript "window.getSelection().toString();" in current tab
                end tell
            end tell
            return selection_text
            """
        }

        return """
        tell application id "\(bundleIdentifier)"
            tell active tab of front window
                set selection_text to execute javascript "window.getSelection().toString();"
            end tell
        end tell
        return selection_text
        """
    }

    private func mapAppleScriptError(_ error: NSDictionary) -> Result<String, SelectionProviderFailure> {
        let errorCode = error[NSAppleScript.errorNumber] as? Int ?? 0
        if errorCode == -1743 {
            return .failure(
                SelectionProviderFailure(
                    .automationPermissionRequired,
                    diagnostics: "appleScriptError=\(errorCode)"
                )
            )
        }

        return .failure(
            SelectionProviderFailure(
                .noText,
                diagnostics: "appleScriptError=\(errorCode)"
            )
        )
    }
}

protocol AXSelectionResolving: Sendable {
    func selectedText(forProcessIdentifier processIdentifier: pid_t) -> Result<String, SelectionProviderFailure>
}

struct AccessibilitySelectionProvider: SelectionProviding {
    let resolver: any AXSelectionResolving

    init(resolver: any AXSelectionResolving = LiveAXSelectionResolver()) {
        self.resolver = resolver
    }

    func selectedText(for target: SelectionTarget?) async -> Result<String, SelectionProviderFailure> {
        guard let target else {
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        }

        return resolver.selectedText(forProcessIdentifier: target.processIdentifier)
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

    static func selectionResult(
        from value: CFTypeRef?,
        error: AXError
    ) -> Result<String, SelectionProviderFailure> {
        switch error {
        case .success:
            if let text = value as? String {
                return .success(text)
            }
            return .failure(SelectionProviderFailure(.noText))
        case .noValue:
            return .failure(SelectionProviderFailure(.noText))
        case .attributeUnsupported:
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        default:
            return .failure(SelectionProviderFailure(.noText))
        }
    }

    static func rangeSelectionResult(
        selectedTextRangeValue: CFTypeRef?,
        selectedTextRangeError: AXError,
        textValue: CFTypeRef?,
        textError: AXError
    ) -> Result<String, SelectionProviderFailure> {
        if selectedTextRangeError == .attributeUnsupported || textError == .attributeUnsupported {
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        }

        guard selectedTextRangeError == .success, textError == .success else {
            return .failure(SelectionProviderFailure(.noText))
        }

        guard let selectedTextRangeValue,
              CFGetTypeID(selectedTextRangeValue) == AXValueGetTypeID(),
              let text = textValue as? String,
              let selectedTextRange = selectedTextRange(from: selectedTextRangeValue),
              let selectedText = substring(text, utf16Range: selectedTextRange) else {
            return .failure(SelectionProviderFailure(.noText))
        }

        return .success(selectedText)
    }

    static func textMarkerSelectionResult(
        selectedTextMarkerRangeValue: CFTypeRef?,
        selectedTextMarkerRangeError: AXError,
        stringValue: CFTypeRef?,
        stringError: AXError
    ) -> Result<String, SelectionProviderFailure> {
        if selectedTextMarkerRangeError == .attributeUnsupported || stringError == .attributeUnsupported {
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        }

        guard selectedTextMarkerRangeError == .success, stringError == .success else {
            return .failure(SelectionProviderFailure(.noText))
        }

        guard let selectedTextMarkerRangeValue,
              CFGetTypeID(selectedTextMarkerRangeValue) == AXTextMarkerRangeGetTypeID(),
              let text = stringValue as? String else {
            return .failure(SelectionProviderFailure(.noText))
        }

        return .success(text)
    }

    private static func selectedTextRange(from value: CFTypeRef) -> CFRange? {
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var selectedTextRange = CFRange()
        let didLoadRange = AXValueGetValue(axValue, .cfRange, &selectedTextRange)
        guard didLoadRange else {
            return nil
        }

        return selectedTextRange
    }

    private static func substring(_ text: String, utf16Range: CFRange) -> String? {
        guard utf16Range.location >= 0, utf16Range.length >= 0 else {
            return nil
        }

        let utf16View = text.utf16
        guard let startUTF16Index = utf16View.index(
            utf16View.startIndex,
            offsetBy: utf16Range.location,
            limitedBy: utf16View.endIndex
        ),
        let endUTF16Index = utf16View.index(
            startUTF16Index,
            offsetBy: utf16Range.length,
            limitedBy: utf16View.endIndex
        ),
        let startIndex = String.Index(startUTF16Index, within: text),
        let endIndex = String.Index(endUTF16Index, within: text) else {
            return nil
        }

        return String(text[startIndex..<endIndex])
    }
}

struct LiveAXSelectionResolver: AXSelectionResolving {
    func selectedText(forProcessIdentifier processIdentifier: pid_t) -> Result<String, SelectionProviderFailure> {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
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
            return .failure(SelectionProviderFailure(.unsupportedHostApp))
        }

        return .failure(SelectionProviderFailure(.noText))
    }

    private func focusedElementLookup(in element: AXUIElement) -> FocusedElementLookup {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        return AccessibilitySelectionProvider.focusedElementLookup(from: value, error: error)
    }

    private func selectedText(from element: AXUIElement) -> Result<String, SelectionProviderFailure> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )

        let directSelection = AccessibilitySelectionProvider.selectionResult(from: value, error: error)
        switch directSelection {
        case .success:
            return directSelection
        case .failure:
            let rangeSelection = selectedTextFromRange(in: element)
            switch rangeSelection {
            case .success:
                return rangeSelection
            case .failure:
                return selectedTextFromTextMarkerRange(in: element)
            }
        }
    }

    private func selectedTextFromRange(in element: AXUIElement) -> Result<String, SelectionProviderFailure> {
        var selectedTextRangeValue: CFTypeRef?
        let selectedTextRangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeValue
        )

        var textValue: CFTypeRef?
        let textError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &textValue
        )

        return AccessibilitySelectionProvider.rangeSelectionResult(
            selectedTextRangeValue: selectedTextRangeValue,
            selectedTextRangeError: selectedTextRangeError,
            textValue: textValue,
            textError: textError
        )
    }

    private func selectedTextFromTextMarkerRange(
        in element: AXUIElement
    ) -> Result<String, SelectionProviderFailure> {
        var selectedTextMarkerRangeValue: CFTypeRef?
        let selectedTextMarkerRangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &selectedTextMarkerRangeValue
        )

        guard selectedTextMarkerRangeError == .success,
              let selectedTextMarkerRangeValue else {
            return AccessibilitySelectionProvider.textMarkerSelectionResult(
                selectedTextMarkerRangeValue: selectedTextMarkerRangeValue,
                selectedTextMarkerRangeError: selectedTextMarkerRangeError,
                stringValue: nil,
                stringError: selectedTextMarkerRangeError
            )
        }

        var stringValue: CFTypeRef?
        let stringError = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
            selectedTextMarkerRangeValue,
            &stringValue
        )

        return AccessibilitySelectionProvider.textMarkerSelectionResult(
            selectedTextMarkerRangeValue: selectedTextMarkerRangeValue,
            selectedTextMarkerRangeError: selectedTextMarkerRangeError,
            stringValue: stringValue,
            stringError: stringError
        )
    }
}

enum FocusedElementLookup {
    case found(AXUIElement)
    case unavailable
    case unsupportedHostApp
}
