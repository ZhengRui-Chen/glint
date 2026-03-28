import Foundation

enum TranslationDirection: Equatable {
    case enToZh
    case zhToEn

    var systemTranslationAvailabilityLabel: String {
        switch self {
        case .enToZh:
            L10n.systemTranslationDirectionEnglishToChinese
        case .zhToEn:
            L10n.systemTranslationDirectionChineseToEnglish
        }
    }

    var targetLanguage: String {
        switch self {
        case .enToZh:
            return "中文"
        case .zhToEn:
            return "English"
        }
    }

    var sourceLocaleLanguage: Locale.Language {
        switch self {
        case .enToZh:
            Locale.Language(identifier: "en")
        case .zhToEn:
            Locale.Language(identifier: "zh")
        }
    }

    var targetLocaleLanguage: Locale.Language {
        switch self {
        case .enToZh:
            Locale.Language(identifier: "zh-Hans")
        case .zhToEn:
            Locale.Language(identifier: "en")
        }
    }
}
