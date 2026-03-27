import CoreGraphics
import Foundation

struct OverlaySizingPolicy: Equatable {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let lineHeight: CGFloat
    let estimatedCharactersPerLine: Int

    init(
        minHeight: CGFloat,
        maxHeight: CGFloat,
        lineHeight: CGFloat = 28,
        estimatedCharactersPerLine: Int = 42
    ) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.lineHeight = lineHeight
        self.estimatedCharactersPerLine = estimatedCharactersPerLine
    }

    static let `default` = OverlaySizingPolicy(minHeight: 180, maxHeight: 420)

    func height(for text: String) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return minHeight
        }

        let estimatedLines = trimmed
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(into: 0) { partialResult, line in
                let characters = max(line.count, 1)
                let wrappedLineCount = Int(
                    ceil(Double(characters) / Double(estimatedCharactersPerLine))
                )
                partialResult += max(wrappedLineCount, 1)
            }

        let rawHeight = minHeight + CGFloat(max(estimatedLines - 1, 0)) * lineHeight
        return min(max(rawHeight, minHeight), maxHeight)
    }
}
