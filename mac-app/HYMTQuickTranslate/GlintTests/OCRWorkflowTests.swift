import CoreGraphics
import XCTest
@testable import Glint
#if canImport(Vision)
import Vision
#endif

final class OCRWorkflowTests: XCTestCase {
    func test_text_normalizer_joins_non_empty_lines() {
        let text = OCRTextNormalizer.normalize(["  Hello  ", "", " world "])

        XCTAssertEqual(text, "Hello\nworld")
    }

    func test_ocr_input_source_returns_trimmed_text() async {
        let inputSource = OCRImageInputSource(
            image: makeTestImage(),
            recognizer: StubOCRRecognizer(
                result: .success(OCRRecognition(text: " 你好 \n世界 ", diagnostics: "obs=2"))
            )
        )

        let result = await inputSource.resolveText()

        XCTAssertEqual(result, .success("你好 \n世界"))
    }

    func test_ocr_input_source_returns_trimmed_recognition_with_diagnostics() async {
        let inputSource = OCRImageInputSource(
            image: makeTestImage(),
            recognizer: StubOCRRecognizer(
                result: .success(OCRRecognition(text: " 你好 \n世界 ", diagnostics: "obs=2"))
            )
        )

        let result = await inputSource.resolveRecognition()

        XCTAssertEqual(
            result,
            .success(OCRRecognition(text: "你好 \n世界", diagnostics: "obs=2"))
        )
    }

    func test_ocr_input_source_reports_no_text_for_whitespace_result() async {
        let inputSource = OCRImageInputSource(
            image: makeTestImage(),
            recognizer: StubOCRRecognizer(
                result: .success(OCRRecognition(text: " \n ", diagnostics: "obs=0"))
            )
        )

        let result = await inputSource.resolveText()

        XCTAssertEqual(result, .failure(TextInputFailure(.noText, diagnostics: "obs=0")))
    }

    func test_prepare_returns_translation_request_for_recognized_ocr_text() async {
        let workflow = TranslateOCRWorkflow(
            recognizer: StubOCRRecognizer(
                result: .success(OCRRecognition(text: "你好", diagnostics: "obs=1"))
            )
        )

        let prepared = await workflow.prepare(image: makeTestImage())

        XCTAssertEqual(
            prepared,
            .translate(OCRRecognition(text: "你好", diagnostics: "obs=1"))
        )
    }

    func test_confirm_translation_returns_plain_translation_result() async {
        let workflow = TranslateOCRWorkflow(
            recognizer: StubOCRRecognizer(
                result: .success(OCRRecognition(text: "你好", diagnostics: "obs=1"))
            ),
            client: StubTranslationClient(result: "hello")
        )

        let state = await workflow.confirmTranslation(
            for: OCRRecognition(text: "你好", diagnostics: "obs=1")
        )

        XCTAssertEqual(state, .result("hello"))
    }

    func test_prepare_returns_plain_error_when_no_text_is_recognized() async {
        let workflow = TranslateOCRWorkflow(
            recognizer: StubOCRRecognizer(
                result: .failure(OCRRecognizerError.noText(diagnostics: "obs=0"))
            )
        )

        let prepared = await workflow.prepare(image: makeTestImage())

        XCTAssertEqual(
            prepared,
            .final(
                .error("No text was recognized in the selected area.")
            )
        )
    }

    #if canImport(Vision)
    func test_vision_request_configures_chinese_and_english_recognition_languages() {
        let request = VisionOCRService.makeRequest()

        XCTAssertEqual(request.recognitionLanguages, ["zh-Hans", "zh-Hant", "en-US"])
        XCTAssertEqual(request.recognitionLevel, .accurate)
        XCTAssertTrue(request.usesLanguageCorrection)
    }
    #endif
}

private struct StubOCRRecognizer: OCRTextRecognizing {
    let result: Result<OCRRecognition, Error>

    func recognizeText(in image: CGImage) async throws -> OCRRecognition {
        try result.get()
    }
}

private struct StubTranslationClient: TranslationClienting {
    let result: String

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        result
    }
}

private func makeTestImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: 8,
        height: 8,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    return context.makeImage()!
}
