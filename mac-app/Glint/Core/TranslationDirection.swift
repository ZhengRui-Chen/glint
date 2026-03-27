enum TranslationDirection: Equatable {
    case enToZh
    case zhToEn

    var targetLanguage: String {
        switch self {
        case .enToZh:
            return "中文"
        case .zhToEn:
            return "English"
        }
    }
}
