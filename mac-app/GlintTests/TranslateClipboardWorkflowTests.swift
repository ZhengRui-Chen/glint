import XCTest
@testable import Glint

final class TranslateClipboardWorkflowTests: XCTestCase {
    func test_workflow_returns_error_when_clipboard_is_empty() async {
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: nil),
            client: StubClient()
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .error(L10n.clipboardDoesNotContainText))
    }

    func test_workflow_translates_medium_text_without_confirmation() async {
        let text = String(repeating: "a", count: 2001)
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: text),
            client: StubClient()
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .result("translated"))
    }

    func test_workflow_translates_very_long_text_without_rejecting() async {
        let text = String(repeating: "a", count: 8001)
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: text),
            client: StubClient()
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .result("translated"))
    }
}

private struct StubClipboard: ClipboardTextReading {
    let text: String?

    func readString() -> String? {
        text
    }
}

private struct StubClient: TranslationClienting {
    func translate(text: String, direction: TranslationDirection) async throws -> String {
        "translated"
    }
}
