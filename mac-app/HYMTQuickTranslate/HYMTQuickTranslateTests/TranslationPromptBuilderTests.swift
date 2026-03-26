import XCTest
@testable import HYMTQuickTranslate

final class TranslationPromptBuilderTests: XCTestCase {
    func test_prompt_builder_uses_translation_only_template() {
        let prompt = TranslationPromptBuilder.makePrompt(
            text: "It is a pleasure to meet you.",
            targetLanguage: "中文"
        )
        XCTAssertTrue(prompt.contains("只需要输出翻译后的结果"))
    }
}
