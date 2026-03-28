import Foundation

enum PreparedTranslation: Equatable {
    case translate(String)
    case final(OverlayViewState)
}

struct TranslateTextWorkflow: Sendable {
    let inputSource: any TextInputSource
    let client: any TranslationClienting
    let policy: TextLengthPolicy
    let detectDirection: @Sendable (String) -> TranslationDirection
    let noTextMessage: String
    let permissionRequiredMessage: String
    let automationPermissionRequiredMessage: String
    let unsupportedHostAppMessage: String
    let ocrUnavailableMessage: String
    let rejectedTextMessage: String

    init(
        inputSource: any TextInputSource,
        client: any TranslationClienting = RuntimeTranslationClient(),
        policy: TextLengthPolicy = .init(softLimit: 2000, hardLimit: 8000),
        detectDirection: @escaping @Sendable (String) -> TranslationDirection = DirectionDetector.detect,
        noTextMessage: String = L10n.noTextProvided,
        permissionRequiredMessage: String? = nil,
        automationPermissionRequiredMessage: String? = nil,
        unsupportedHostAppMessage: String? = nil,
        ocrUnavailableMessage: String? = nil,
        rejectedTextMessage: String = L10n.textExceedsMaximumLength
    ) {
        self.inputSource = inputSource
        self.client = client
        self.policy = policy
        self.detectDirection = detectDirection
        self.noTextMessage = noTextMessage
        self.permissionRequiredMessage = permissionRequiredMessage ?? noTextMessage
        self.automationPermissionRequiredMessage = automationPermissionRequiredMessage ?? noTextMessage
        self.unsupportedHostAppMessage = unsupportedHostAppMessage ?? noTextMessage
        self.ocrUnavailableMessage = ocrUnavailableMessage ?? noTextMessage
        self.rejectedTextMessage = rejectedTextMessage
    }

    func run() async -> OverlayViewState {
        switch await prepare() {
        case let .translate(text):
            return await translate(text)
        case let .final(state):
            return state
        }
    }

    func prepare() async -> PreparedTranslation {
        switch await inputSource.resolveText() {
        case let .success(text):
            switch policy.evaluate(text) {
            case .allowed:
                return .translate(text)
            case .needsConfirmation:
                return .final(.confirmLongText(text))
            case .rejected:
                return .final(.error(rejectedTextMessage))
            }
        case let .failure(failure):
            return .final(.error(message(for: failure)))
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
            case .missingConfiguration:
                return .error(L10n.localTranslationServiceUnavailable)
            case .invalidResponse, .emptyChoices:
                return .error(L10n.localTranslationServiceInvalidResponse)
            case .invalidStatusCode:
                return .error(L10n.localTranslationServiceUnavailable)
            case .systemTranslationUnavailable:
                return .error(L10n.systemTranslationUnavailable)
            case .systemTranslationFailed:
                return .error(L10n.systemTranslationFailed)
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .error(L10n.translationRequestTimedOut)
            default:
                return .error(L10n.localTranslationServiceUnavailable)
            }
        } catch {
            return .error(L10n.localTranslationServiceUnavailable)
        }
    }

    private func message(for failure: TextInputFailure) -> String {
        let baseMessage: String
        switch failure.error {
        case .noText:
            baseMessage = noTextMessage
        case .permissionRequired:
            baseMessage = permissionRequiredMessage
        case .automationPermissionRequired:
            baseMessage = automationPermissionRequiredMessage
        case .unsupportedHostApp:
            baseMessage = unsupportedHostAppMessage
        case .ocrUnavailable:
            baseMessage = ocrUnavailableMessage
        }

        guard let diagnostics = failure.diagnostics,
              !diagnostics.isEmpty else {
            return baseMessage
        }

        return """
        \(baseMessage)
        Diagnostics: \(diagnostics)
        """
    }
}

struct TranslateClipboardWorkflow: Sendable {
    private let workflow: TranslateTextWorkflow

    init(
        clipboard: any ClipboardTextReading = ClipboardTextReader(),
        client: any TranslationClienting = RuntimeTranslationClient(),
        policy: TextLengthPolicy = .init(softLimit: 2000, hardLimit: 8000),
        detectDirection: @escaping @Sendable (String) -> TranslationDirection = DirectionDetector.detect
    ) {
        self.workflow = TranslateTextWorkflow(
            inputSource: ClipboardInputSource(clipboard: clipboard),
            client: client,
            policy: policy,
            detectDirection: detectDirection,
            noTextMessage: L10n.clipboardDoesNotContainText,
            rejectedTextMessage: L10n.clipboardTextExceedsMaximumLength
        )
    }

    func handleShortcut() async -> OverlayViewState {
        await workflow.run()
    }

    func confirmTranslation(for text: String) async -> OverlayViewState {
        await workflow.confirmTranslation(for: text)
    }
}
