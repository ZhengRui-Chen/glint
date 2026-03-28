import CoreGraphics
import Foundation

private final class OCRImageBox: @unchecked Sendable {
    let image: CGImage

    init(image: CGImage) {
        self.image = image
    }
}

private struct StaticTextInputSource: TextInputSource {
    let text: String

    func resolveText() async -> Result<String, TextInputFailure> {
        .success(text)
    }
}

struct OCRImageInputSource: TextInputSource {
    private let imageBox: OCRImageBox
    private let recognizer: any OCRTextRecognizing

    init(
        image: CGImage,
        recognizer: any OCRTextRecognizing = VisionOCRService()
    ) {
        self.imageBox = OCRImageBox(image: image)
        self.recognizer = recognizer
    }

    func resolveRecognition() async -> Result<OCRRecognition, TextInputFailure> {
        do {
            let recognition = try await recognizer.recognizeText(in: imageBox.image)
            let normalized = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                return .failure(
                    TextInputFailure(.noText, diagnostics: recognition.diagnostics)
                )
            }
            return .success(
                OCRRecognition(text: normalized, diagnostics: recognition.diagnostics)
            )
        } catch let error as OCRRecognizerError {
            switch error {
            case let .noText(diagnostics):
                return .failure(TextInputFailure(.noText, diagnostics: diagnostics))
            case .unavailable:
                return .failure(TextInputFailure(.ocrUnavailable))
            case let .recognitionFailed(diagnostics):
                return .failure(TextInputFailure(.ocrUnavailable, diagnostics: diagnostics))
            }
        } catch {
            return .failure(TextInputFailure(.ocrUnavailable, diagnostics: String(describing: error)))
        }
    }

    func resolveText() async -> Result<String, TextInputFailure> {
        switch await resolveRecognition() {
        case let .success(recognition):
            return .success(recognition.text)
        case let .failure(failure):
            return .failure(failure)
        }
    }
}

enum PreparedOCRTranslation: Equatable {
    case translate(OCRRecognition)
    case final(OverlayViewState)
}

struct TranslateOCRWorkflow: Sendable {
    let recognizer: any OCRTextRecognizing
    let client: any TranslationClienting
    let detectDirection: @Sendable (String) -> TranslationDirection

    init(
        recognizer: any OCRTextRecognizing = VisionOCRService(),
        client: any TranslationClienting = RuntimeTranslationClient(),
        detectDirection: @escaping @Sendable (String) -> TranslationDirection = DirectionDetector.detect
    ) {
        self.recognizer = recognizer
        self.client = client
        self.detectDirection = detectDirection
    }

    func prepare(image: CGImage) async -> PreparedOCRTranslation {
        let inputSource = OCRImageInputSource(image: image, recognizer: recognizer)

        switch await inputSource.resolveRecognition() {
        case let .success(recognition):
            return .translate(recognition)
        case let .failure(failure):
            return .final(.error(message(for: failure)))
        }
    }

    func confirmTranslation(for recognition: OCRRecognition) async -> OverlayViewState {
        await makeWorkflow(
            inputSource: StaticTextInputSource(text: recognition.text)
        ).confirmTranslation(for: recognition.text)
    }

    private func makeWorkflow(inputSource: any TextInputSource) -> TranslateTextWorkflow {
        TranslateTextWorkflow(
            inputSource: inputSource,
            client: client,
            detectDirection: detectDirection,
            noTextMessage: L10n.noTextRecognizedInSelectedArea,
            ocrUnavailableMessage: L10n.ocrUnavailableOnSystem
        )
    }

    private func message(for failure: TextInputFailure) -> String {
        let baseMessage: String
        switch failure.error {
        case .noText:
            baseMessage = L10n.noTextRecognizedInSelectedArea
        case .ocrUnavailable:
            baseMessage = L10n.ocrUnavailableOnSystem
        case .permissionRequired, .automationPermissionRequired, .unsupportedHostApp:
            baseMessage = L10n.ocrUnavailableOnSystem
        }

        guard let diagnostics = failure.diagnostics,
              !diagnostics.isEmpty else {
            return baseMessage
        }

        _ = diagnostics
        return baseMessage
    }
}
