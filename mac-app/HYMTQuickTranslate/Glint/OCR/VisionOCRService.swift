import CoreGraphics
import Foundation
#if canImport(Vision)
import Vision
#endif

enum OCRRecognizerError: Error, Equatable {
    case noText(diagnostics: String? = nil)
    case unavailable
    case recognitionFailed(String? = nil)
}

struct OCRRecognition: Equatable, Sendable {
    let text: String
    let diagnostics: String?
}

protocol OCRTextRecognizing: Sendable {
    func recognizeText(in image: CGImage) async throws -> OCRRecognition
}

enum OCRTextNormalizer {
    static func normalize(_ lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

enum OCRDiagnosticsFormatter {
    static func format(
        observations: [VNRecognizedTextObservation],
        imageSize: CGSize
    ) -> String {
        let header = "image=\(Int(imageSize.width))x\(Int(imageSize.height)), observations=\(observations.count)"
        let body = observations.enumerated().map { index, observation in
            let box = observation.boundingBox
            let candidates = observation.topCandidates(3).map { candidate in
                "[\(String(format: "%.2f", candidate.confidence))] \(candidate.string)"
            }.joined(separator: " | ")
            return """
            [\(index)] box=(x:\(String(format: "%.3f", box.minX)), y:\(String(format: "%.3f", box.minY)), w:\(String(format: "%.3f", box.width)), h:\(String(format: "%.3f", box.height))) candidates=\(candidates)
            """
        }

        guard body.isEmpty == false else {
            return header
        }

        return ([header] + body).joined(separator: "\n")
    }
}

struct VisionOCRService: OCRTextRecognizing {
    static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        return request
    }

    func recognizeText(in image: CGImage) async throws -> OCRRecognition {
        #if canImport(Vision)
        let request = Self.makeRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRRecognizerError.recognitionFailed(String(describing: error))
        }

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let normalized = OCRTextNormalizer.normalize(lines)
        let diagnostics = OCRDiagnosticsFormatter.format(
            observations: observations,
            imageSize: CGSize(width: image.width, height: image.height)
        )
        return OCRRecognition(text: normalized, diagnostics: diagnostics)
        #else
        throw OCRRecognizerError.unavailable
        #endif
    }
}
