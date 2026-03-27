import Foundation

enum DirectionDetector {
    static func detect(_ text: String) -> TranslationDirection {
        let hanCount = text.unicodeScalars.reduce(into: 0) { count, scalar in
            if scalar.isHanCharacter {
                count += 1
            }
        }
        let latinCount = text.unicodeScalars.reduce(into: 0) { count, scalar in
            if scalar.isASCII && CharacterSet.letters.contains(scalar) {
                count += 1
            }
        }

        // 保持弱信号场景偏向 en->zh，贴近主使用场景。
        if hanCount >= 2 && hanCount > latinCount {
            return .zhToEn
        }
        if latinCount >= 3 && latinCount > hanCount {
            return .enToZh
        }
        return .enToZh
    }
}

private extension Unicode.Scalar {
    var isHanCharacter: Bool {
        switch value {
        case 0x3400 ... 0x4DBF,
             0x4E00 ... 0x9FFF,
             0xF900 ... 0xFAFF,
             0x20000 ... 0x2A6DF,
             0x2A700 ... 0x2B73F,
             0x2B740 ... 0x2B81F,
             0x2B820 ... 0x2CEAF,
             0x2CEB0 ... 0x2EBEF,
             0x30000 ... 0x3134F:
            return true
        default:
            return false
        }
    }
}
