import XCTest
@testable import HYMTQuickTranslate

final class TranslateClipboardWorkflowTests: XCTestCase {
    func test_workflow_returns_error_when_clipboard_is_empty() async {
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: nil),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .error("Clipboard does not contain text."))
    }

    func test_workflow_requires_confirmation_for_medium_text() async {
        let text = String(repeating: "a", count: 2001)
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: text),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .confirmLongText(text))
    }

    func test_workflow_returns_clipboard_specific_error_when_text_exceeds_hard_limit() async {
        let text = String(repeating: "a", count: 8001)
        let workflow = TranslateClipboardWorkflow(
            clipboard: StubClipboard(text: text),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let state = await workflow.handleShortcut()

        XCTAssertEqual(state, .error("Clipboard text exceeds the maximum length."))
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
