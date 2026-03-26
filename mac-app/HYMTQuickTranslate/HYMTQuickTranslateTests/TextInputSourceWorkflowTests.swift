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
