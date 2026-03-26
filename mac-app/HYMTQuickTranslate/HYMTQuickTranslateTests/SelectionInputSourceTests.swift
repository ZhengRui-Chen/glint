import XCTest
@testable import HYMTQuickTranslate

final class SelectionInputSourceTests: XCTestCase {
    func test_selection_input_reports_missing_permission() async {
        let provider = StubSelectionProvider(result: .failure(.noText))
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: false),
            provider: provider
        )

        let result = await source.resolveText()
        let callCount = await provider.recordedCallCount()

        XCTAssertEqual(result, .failure(.permissionRequired))
        XCTAssertEqual(callCount, 0)
    }

    func test_selection_input_reports_missing_selection() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .failure(.noText))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .failure(.noText))
    }

    func test_selection_input_reports_unsupported_host_app() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .failure(.unsupportedHostApp))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .failure(.unsupportedHostApp))
    }

    func test_selection_input_returns_trimmed_text() async {
        let source = SelectionInputSource(
            permission: StubAccessibilityPermission(isGranted: true),
            provider: StubSelectionProvider(result: .success("  Hello world  \n"))
        )

        let result = await source.resolveText()

        XCTAssertEqual(result, .success("Hello world"))
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
        let result: Result<String, SelectionProviderError> = AccessibilitySelectionProvider.selectionResult(
            from: nil,
            error: .cannotComplete
        )

        XCTAssertEqual(result, .failure(.noText))
    }
}

private struct StubAccessibilityPermission: AccessibilityPermissionChecking {
    let isGranted: Bool
}

private actor StubSelectionProvider: SelectionProviding {
    let result: Result<String, SelectionProviderError>
    private var callCount = 0

    init(result: Result<String, SelectionProviderError>) {
        self.result = result
    }

    func selectedText() async -> Result<String, SelectionProviderError> {
        callCount += 1
        return result
    }

    func recordedCallCount() -> Int {
        callCount
    }
}
