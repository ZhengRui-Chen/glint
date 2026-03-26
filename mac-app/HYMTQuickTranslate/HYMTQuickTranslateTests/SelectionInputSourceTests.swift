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
