import XCTest
@testable import HYMTQuickTranslate

final class TextInputSourceWorkflowTests: XCTestCase {
    func test_workflow_returns_error_when_input_source_has_no_text() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(.noText)),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )
        let state = await workflow.run()
        XCTAssertEqual(state, .error("No text was provided."))
    }

    func test_workflow_returns_generic_error_when_non_clipboard_text_exceeds_hard_limit() async {
        let text = String(repeating: "a", count: 8001)
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .success(text)),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let state = await workflow.run()

        XCTAssertEqual(state, .error("Text exceeds the maximum length."))
    }
}

private struct StubTextInputSource: TextInputSource {
    let result: Result<String, TextInputSourceError>

    func resolveText() async -> Result<String, TextInputSourceError> {
        result
    }
}

private struct StubClient: TranslationClienting {
    func translate(text: String, direction: TranslationDirection) async throws -> String {
        "translated"
    }
}
