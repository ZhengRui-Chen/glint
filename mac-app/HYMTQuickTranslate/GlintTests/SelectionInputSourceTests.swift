import XCTest
@testable import Glint

final class SelectionInputSourceTests: XCTestCase {
    func test_selection_input_reports_missing_permission() async {
        let provider = StubSelectionProvider(result: .failure(SelectionProviderFailure(.noText)))
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: false),
            provider: provider
        )

        let result = await source.resolveText()
        let callCount = await provider.recordedCallCount()

        XCTAssertEqual(result, .failure(TextInputFailure(.permissionRequired)))
        XCTAssertEqual(callCount, 0)
    }

    func test_selection_input_reports_missing_selection() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.noText)))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .failure(TextInputFailure(.noText)))
    }

    func test_selection_input_reports_unsupported_host_app() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.unsupportedHostApp)))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .failure(TextInputFailure(.unsupportedHostApp)))
    }

    func test_selection_input_returns_trimmed_text() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .success("  Hello world  \n"))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .success("Hello world"))
    }

    func test_selection_input_preserves_provider_diagnostics() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(
                result: .failure(
                    SelectionProviderFailure(
                        .unsupportedHostApp,
                        diagnostics: "frontmostApp=com.apple.Safari | browserFallback=failed:noText"
                    )
                )
            )
        )

        let result = await source.resolveText()

        XCTAssertEqual(
            result,
            .failure(
                TextInputFailure(
                    .unsupportedHostApp,
                    diagnostics: "frontmostApp=com.apple.Safari | browserFallback=failed:noText"
                )
            )
        )
    }

    func test_browser_fallback_provider_uses_browser_selection_when_accessibility_is_unsupported() async {
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.unsupportedHostApp))),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: BrowserAppleScriptSelectionProvider.safariBundleIdentifier),
            browserSelectionProvider: StubBrowserSelectionProvider(result: .success("browser selection"))
        )
        let target = SelectionTarget(
            processIdentifier: 1,
            bundleIdentifier: BrowserAppleScriptSelectionProvider.safariBundleIdentifier
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(result, .success("browser selection"))
    }

    func test_browser_fallback_provider_returns_accessibility_result_for_non_browser_apps() async {
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.unsupportedHostApp))),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: "com.apple.dt.Xcode"),
            browserSelectionProvider: StubBrowserSelectionProvider(result: .success("browser selection"))
        )
        let target = SelectionTarget(
            processIdentifier: 2,
            bundleIdentifier: "com.apple.dt.Xcode"
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(
            result,
            .failure(
                SelectionProviderFailure(
                    .unsupportedHostApp,
                    diagnostics: "frontmostApp=com.apple.dt.Xcode | accessibility=unsupportedHostApp | browserFallback=skipped:unsupportedBrowser"
                )
            )
        )
    }

    func test_browser_fallback_provider_keeps_accessibility_success_without_browser_lookup() async {
        let browserProvider = StubBrowserSelectionProvider(result: .success("browser selection"))
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .success("ax selection")),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: BrowserAppleScriptSelectionProvider.chromeBundleIdentifier),
            browserSelectionProvider: browserProvider
        )
        let target = SelectionTarget(
            processIdentifier: 3,
            bundleIdentifier: BrowserAppleScriptSelectionProvider.chromeBundleIdentifier
        )

        let result = await provider.selectedText(for: target)
        let callCount = await browserProvider.recordedCallCount()

        XCTAssertEqual(result, .success("ax selection"))
        XCTAssertEqual(callCount, 0)
    }

    func test_browser_fallback_provider_reports_automation_permission_diagnostics() async {
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.unsupportedHostApp))),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: BrowserAppleScriptSelectionProvider.safariBundleIdentifier),
            browserSelectionProvider: StubBrowserSelectionProvider(
                result: .failure(
                    SelectionProviderFailure(
                        .automationPermissionRequired,
                        diagnostics: "appleScriptError=-1743"
                    )
                )
            )
        )
        let target = SelectionTarget(
            processIdentifier: 4,
            bundleIdentifier: BrowserAppleScriptSelectionProvider.safariBundleIdentifier
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(
            result,
            .failure(
                SelectionProviderFailure(
                    .automationPermissionRequired,
                    diagnostics: "frontmostApp=com.apple.Safari | accessibility=unsupportedHostApp | browserFallback=failed:automationPermissionRequired | appleScriptError=-1743"
                )
            )
        )
    }

    func test_browser_fallback_provider_converts_empty_accessibility_success_into_diagnostic_no_text() async {
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .success("   ")),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: "com.microsoft.VSCode"),
            browserSelectionProvider: StubBrowserSelectionProvider(result: .success("browser selection"))
        )
        let target = SelectionTarget(
            processIdentifier: 5,
            bundleIdentifier: "com.microsoft.VSCode"
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(
            result,
            .failure(
                SelectionProviderFailure(
                    .noText,
                    diagnostics: "frontmostApp=com.microsoft.VSCode | accessibility=noText | browserFallback=skipped:unsupportedBrowser"
                )
            )
        )
    }

    func test_accessibility_provider_handles_non_axui_element_focus_value_safely() {
        let lookup = AccessibilitySelectionProvider.focusedElementLookup(
            from: "not-an-element" as CFTypeRef,
            error: .success
        )

        guard case .unavailable = lookup else {
            return XCTFail("Expected non-AXUIElement focus value to be treated as unavailable.")
        }
    }

    func test_accessibility_provider_does_not_report_generic_ax_failure_as_unsupported_host_app() {
        let result: Result<String, SelectionProviderFailure> = AccessibilitySelectionProvider.selectionResult(
            from: nil,
            error: .cannotComplete
        )

        XCTAssertEqual(result, .failure(SelectionProviderFailure(.noText)))
    }

    func test_accessibility_provider_falls_back_to_selected_text_range_and_value() {
        var selectedRange = CFRange(location: 6, length: 5)
        let selectedRangeValue = AXValueCreate(.cfRange, &selectedRange)

        let result = AccessibilitySelectionProvider.rangeSelectionResult(
            selectedTextRangeValue: selectedRangeValue,
            selectedTextRangeError: .success,
            textValue: "Hello world" as CFTypeRef,
            textError: .success
        )

        XCTAssertEqual(result, .success("world"))
    }

    func test_accessibility_provider_reports_unsupported_host_when_selected_text_range_is_unsupported() {
        let result = AccessibilitySelectionProvider.rangeSelectionResult(
            selectedTextRangeValue: nil,
            selectedTextRangeError: .attributeUnsupported,
            textValue: "Hello world" as CFTypeRef,
            textError: .success
        )

        XCTAssertEqual(result, .failure(SelectionProviderFailure(.unsupportedHostApp)))
    }

    func test_accessibility_provider_reads_selected_text_from_text_marker_range() {
        let markerRange = AXTextMarkerRangeCreateWithBytes(
            kCFAllocatorDefault,
            [0x01],
            1,
            [0x02],
            1
        )

        let result = AccessibilitySelectionProvider.textMarkerSelectionResult(
            selectedTextMarkerRangeValue: markerRange,
            selectedTextMarkerRangeError: .success,
            stringValue: "marker text" as CFTypeRef,
            stringError: .success
        )

        XCTAssertEqual(result, .success("marker text"))
    }

    func test_accessibility_provider_reports_unsupported_host_when_text_marker_range_is_unsupported() {
        let result = AccessibilitySelectionProvider.textMarkerSelectionResult(
            selectedTextMarkerRangeValue: nil,
            selectedTextMarkerRangeError: .attributeUnsupported,
            stringValue: nil,
            stringError: .attributeUnsupported
        )

        XCTAssertEqual(result, .failure(SelectionProviderFailure(.unsupportedHostApp)))
    }

    func test_browser_fallback_provider_uses_captured_target_when_frontmost_app_has_changed() async {
        let provider = BrowserFallbackSelectionProvider(
            accessibilityProvider: StubSelectionProvider(result: .failure(SelectionProviderFailure(.unsupportedHostApp))),
            frontmostAppProvider: StubFrontmostAppProvider(bundleIdentifier: "com.apple.dt.Xcode"),
            browserSelectionProvider: StubBrowserSelectionProvider(result: .success("browser selection"))
        )
        let target = SelectionTarget(
            processIdentifier: 42,
            bundleIdentifier: BrowserAppleScriptSelectionProvider.safariBundleIdentifier
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(result, .success("browser selection"))
    }

    func test_accessibility_provider_uses_captured_target_instead_of_live_frontmost_lookup() async {
        let provider = AccessibilitySelectionProvider(
            resolver: StubAXSelectionResolver(
                result: .success("captured selection")
            )
        )
        let target = SelectionTarget(
            processIdentifier: 99,
            bundleIdentifier: "com.pdfeditor.pdfeditormac"
        )

        let result = await provider.selectedText(for: target)

        XCTAssertEqual(result, .success("captured selection"))
    }
}

private struct StubAccessibilityPermission: AccessibilityPermissionChecking {
    let isGranted: Bool
}

private actor StubSelectionProvider: SelectionProviding {
    let result: Result<String, SelectionProviderFailure>
    private var callCount = 0

    init(result: Result<String, SelectionProviderFailure>) {
        self.result = result
    }

    func selectedText(for target: SelectionTarget?) async -> Result<String, SelectionProviderFailure> {
        _ = target
        callCount += 1
        return result
    }

    func recordedCallCount() -> Int {
        callCount
    }
}

private struct StubFrontmostAppProvider: FrontmostAppProviding {
    let bundleIdentifier: String?

    func frontmostBundleIdentifier() -> String? {
        bundleIdentifier
    }
}

private actor StubBrowserSelectionProvider: BrowserSelectionProviding {
    let result: Result<String, SelectionProviderFailure>
    private var callCount = 0

    init(result: Result<String, SelectionProviderFailure>) {
        self.result = result
    }

    func selectedText(for bundleIdentifier: String) async -> Result<String, SelectionProviderFailure> {
        _ = bundleIdentifier
        callCount += 1
        return result
    }

    func recordedCallCount() -> Int {
        callCount
    }
}

private struct StubAXSelectionResolver: AXSelectionResolving {
    let result: Result<String, SelectionProviderFailure>

    func selectedText(forProcessIdentifier processIdentifier: pid_t) -> Result<String, SelectionProviderFailure> {
        _ = processIdentifier
        return result
    }
}
