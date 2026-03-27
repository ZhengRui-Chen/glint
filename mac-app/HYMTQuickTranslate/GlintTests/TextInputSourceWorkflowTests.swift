import XCTest
@testable import Glint

final class TextInputSourceWorkflowTests: XCTestCase {
    func test_workflow_returns_error_when_input_source_has_no_text() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(TextInputFailure(.noText))),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )
        let state = await workflow.run()
        XCTAssertEqual(state, .error(L10n.noTextProvided))
    }

    func test_workflow_returns_generic_error_when_non_clipboard_text_exceeds_hard_limit() async {
        let text = String(repeating: "a", count: 8001)
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .success(text)),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let state = await workflow.run()

        XCTAssertEqual(state, .error(L10n.textExceedsMaximumLength))
    }

    func test_prepare_returns_translation_request_for_allowed_text() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .success("hello")),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000)
        )

        let prepared = await workflow.prepare()

        XCTAssertEqual(prepared, .translate("hello"))
    }

    func test_prepare_returns_final_error_for_failed_input() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(
                result: .failure(
                    TextInputFailure(
                        .unsupportedHostApp,
                        diagnostics: "frontmostApp=com.brave.Browser"
                    )
                )
            ),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            automationPermissionRequiredMessage: "Browser automation permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let prepared = await workflow.prepare()

        XCTAssertEqual(
            prepared,
            .final(
                .error(
                    """
                    Frontmost app does not expose selected text through Accessibility APIs.
                    Diagnostics: frontmostApp=com.brave.Browser
                    """
                )
            )
        )
    }

    func test_workflow_returns_permission_specific_error() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(TextInputFailure(.permissionRequired))),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let state = await workflow.run()

        XCTAssertEqual(state, .error("Accessibility permission is not granted."))
    }

    func test_workflow_returns_unsupported_host_app_error() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(TextInputFailure(.unsupportedHostApp))),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            automationPermissionRequiredMessage: "Browser automation permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let state = await workflow.run()

        XCTAssertEqual(
            state,
            .error("Frontmost app does not expose selected text through Accessibility APIs.")
        )
    }

    func test_workflow_returns_automation_permission_error() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(result: .failure(TextInputFailure(.automationPermissionRequired))),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            automationPermissionRequiredMessage: "Browser automation permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let state = await workflow.run()

        XCTAssertEqual(state, .error("Browser automation permission is not granted."))
    }

    func test_workflow_appends_diagnostics_to_error_message() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(
                result: .failure(
                    TextInputFailure(
                        .unsupportedHostApp,
                        diagnostics: "frontmostApp=com.apple.Safari | browserFallback=failed:automationPermissionRequired"
                    )
                )
            ),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            automationPermissionRequiredMessage: "Browser automation permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let state = await workflow.run()

        XCTAssertEqual(
            state,
            .error(
                """
                Frontmost app does not expose selected text through Accessibility APIs.
                Diagnostics: frontmostApp=com.apple.Safari | browserFallback=failed:automationPermissionRequired
                """
            )
        )
    }

    func test_workflow_appends_diagnostics_to_no_text_message() async {
        let workflow = TranslateTextWorkflow(
            inputSource: StubTextInputSource(
                result: .failure(
                    TextInputFailure(
                        .noText,
                        diagnostics: "frontmostApp=com.microsoft.VSCode | accessibility=noText | browserFallback=skipped:unsupportedBrowser"
                    )
                )
            ),
            client: StubClient(),
            policy: .init(softLimit: 2000, hardLimit: 8000),
            noTextMessage: "No selected text was found.",
            permissionRequiredMessage: "Accessibility permission is not granted.",
            automationPermissionRequiredMessage: "Browser automation permission is not granted.",
            unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs."
        )

        let state = await workflow.run()

        XCTAssertEqual(
            state,
            .error(
                """
                No selected text was found.
                Diagnostics: frontmostApp=com.microsoft.VSCode | accessibility=noText | browserFallback=skipped:unsupportedBrowser
                """
            )
        )
    }
}

private struct StubTextInputSource: TextInputSource {
    let result: Result<String, TextInputFailure>

    func resolveText() async -> Result<String, TextInputFailure> {
        result
    }
}

private struct StubClient: TranslationClienting {
    func translate(text: String, direction: TranslationDirection) async throws -> String {
        "translated"
    }
}
