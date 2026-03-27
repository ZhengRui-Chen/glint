struct TranslationPromptBuilder {
    static func makePrompt(text: String, targetLanguage: String) -> String {
        "将以下文本翻译为\(targetLanguage)，注意只需要输出翻译后的结果，不要额外解释：\n\n\(text)"
    }
}
