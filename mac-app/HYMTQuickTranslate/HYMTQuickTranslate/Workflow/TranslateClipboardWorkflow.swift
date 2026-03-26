import Foundation

struct TranslateTextWorkflow: Sendable {
    let inputSource: any TextInputSource
    let client: any TranslationClienting
    let policy: TextLengthPolicy
    let detectDirection: @Sendable (String) -> TranslationDirection
    let noTextMessage: String
    let rejectedTextMessage: String

    init(
        inputSource: any TextInputSource,
        client: any TranslationClienting = LocalTranslationClient(),
        policy: TextLengthPolicy = .init(softLimit: 2000, hardLimit: 8000),
        detectDirection: @escaping @Sendable (String) -> TranslationDirection = DirectionDetector.detect,
        noTextMessage: String = "No text was provided.",
        rejectedTextMessage: String = "Text exceeds the maximum length."
    ) {
        self.inputSource = inputSource
        self.client = client
        self.policy = policy
        self.detectDirection = detectDirection
        self.noTextMessage = noTextMessage
        self.rejectedTextMessage = rejectedTextMessage
    }

    func run() async -> OverlayViewState {
        switch await inputSource.resolveText() {
        case let .success(text):
            switch policy.evaluate(text) {
            case .allowed:
                return await translate(text)
            case .needsConfirmation:
                return .confirmLongText(text)
            case .rejected:
                return .error(rejectedTextMessage)
            }
        case .failure:
            return .error(noTextMessage)
        }
    }

    func confirmTranslation(for text: String) async -> OverlayViewState {
        await translate(text)
    }

    private func translate(_ text: String) async -> OverlayViewState {
        do {
            let direction = detectDirection(text)
            let result = try await client.translate(text: text, direction: direction)
            return .result(result)
        } catch let error as LocalTranslationClientError {
            switch error {
            case .invalidResponse, .emptyChoices:
                return .error("Local translation service returned an invalid response.")
            case .invalidStatusCode:
                return .error("Local translation service is unavailable.")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .error("Translation request timed out.")
            default:
                return .error("Local translation service is unavailable.")
            }
        } catch {
            return .error("Local translation service is unavailable.")
        }
    }
}

struct TranslateClipboardWorkflow: Sendable {
    private let workflow: TranslateTextWorkflow

    init(
        clipboard: any ClipboardTextReading = ClipboardTextReader(),
        client: any TranslationClienting = LocalTranslationClient(),
        policy: TextLengthPolicy = .init(softLimit: 2000, hardLimit: 8000),
        detectDirection: @escaping @Sendable (String) -> TranslationDirection = DirectionDetector.detect
    ) {
        self.workflow = TranslateTextWorkflow(
            inputSource: ClipboardInputSource(clipboard: clipboard),
            client: client,
            policy: policy,
            detectDirection: detectDirection,
            noTextMessage: "Clipboard does not contain text.",
            rejectedTextMessage: "Clipboard text exceeds the maximum length."
        )
    }

    func handleShortcut() async -> OverlayViewState {
        await workflow.run()
    }

    func confirmTranslation(for text: String) async -> OverlayViewState {
        await workflow.confirmTranslation(for: text)
    }
}
