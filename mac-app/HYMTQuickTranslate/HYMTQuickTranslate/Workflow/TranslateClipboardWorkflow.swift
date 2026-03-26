import Foundation

struct TranslateClipboardWorkflow {
    let clipboard: any ClipboardTextReading
    let client: any TranslationClienting
    let policy: TextLengthPolicy
    let detectDirection: (String) -> TranslationDirection

    init(
        clipboard: any ClipboardTextReading = ClipboardTextReader(),
        client: any TranslationClienting = LocalTranslationClient(),
        policy: TextLengthPolicy = .init(softLimit: 2000, hardLimit: 8000),
        detectDirection: @escaping (String) -> TranslationDirection = DirectionDetector.detect
    ) {
        self.clipboard = clipboard
        self.client = client
        self.policy = policy
        self.detectDirection = detectDirection
    }

    func handleShortcut() async -> OverlayViewState {
        guard let text = clipboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .error("Clipboard does not contain text.")
        }

        switch policy.evaluate(text) {
        case .allowed:
            return await translate(text)
        case .needsConfirmation:
            return .confirmLongText(text)
        case .rejected:
            return .error("Clipboard text exceeds the maximum length.")
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
