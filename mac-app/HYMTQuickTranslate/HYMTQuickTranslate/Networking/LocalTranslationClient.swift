import Foundation

protocol TranslationClienting {
    func translate(text: String, direction: TranslationDirection) async throws -> String
}

enum LocalTranslationClientError: Error, Equatable {
    case invalidResponse
    case invalidStatusCode(Int)
    case emptyChoices
}

struct LocalTranslationClient: TranslationClienting {
    let config: AppConfig
    let session: URLSession

    init(config: AppConfig = .default, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        let prompt = TranslationPromptBuilder.makePrompt(
            text: text,
            targetLanguage: direction.targetLanguage
        )
        let payload = ChatCompletionRequest(
            model: config.model,
            messages: [
                ChatMessage(role: "user", content: prompt)
            ],
            maxTokens: 256,
            temperature: 0.2
        )

        var request = URLRequest(
            url: config.baseURL.appendingPathComponent("v1/chat/completions")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = config.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalTranslationClientError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LocalTranslationClientError.invalidStatusCode(httpResponse.statusCode)
        }
        return try Self.decodeContent(from: data)
    }

    static func decodeContent(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw LocalTranslationClientError.emptyChoices
        }
        return content
    }
}
