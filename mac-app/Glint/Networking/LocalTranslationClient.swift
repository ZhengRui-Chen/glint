import Foundation

protocol TranslationClienting: Sendable {
    func translate(text: String, direction: TranslationDirection) async throws -> String
}

enum LocalTranslationClientError: Error, Equatable {
    case missingConfiguration
    case invalidResponse
    case invalidStatusCode(Int)
    case emptyChoices
    case systemTranslationUnavailable
    case systemTranslationFailed
}

struct LocalTranslationClient: TranslationClienting, Sendable {
    let session: URLSession
    private let configProvider: @Sendable () -> AppConfig

    init(
        session: URLSession = .shared,
        configProvider: @escaping @Sendable () -> AppConfig = { AppConfig.default }
    ) {
        self.session = session
        self.configProvider = configProvider
    }

    init(
        config: AppConfig,
        session: URLSession = .shared
    ) {
        self.session = session
        configProvider = { config }
    }

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        let config = configProvider()
        guard !config.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalTranslationClientError.missingConfiguration
        }

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
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
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

struct RuntimeTranslationClient: TranslationClienting, Sendable {
    private let configProvider: @Sendable () -> AppConfig
    private let makeCustomAPIClient: @Sendable (AppConfig) -> any TranslationClienting
    private let systemTranslationClient: any TranslationClienting

    init(
        configProvider: @escaping @Sendable () -> AppConfig = { AppConfig.default },
        makeCustomAPIClient: @escaping @Sendable (AppConfig) -> any TranslationClienting = { config in
            LocalTranslationClient(config: config)
        },
        systemTranslationClient: any TranslationClienting = SystemTranslationClient()
    ) {
        self.configProvider = configProvider
        self.makeCustomAPIClient = makeCustomAPIClient
        self.systemTranslationClient = systemTranslationClient
    }

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        let config = configProvider()
        switch config.provider {
        case .customAPI:
            return try await makeCustomAPIClient(config).translate(text: text, direction: direction)
        case .system:
            return try await systemTranslationClient.translate(text: text, direction: direction)
        }
    }
}

struct SystemTranslationClient: TranslationClienting, Sendable {
    func translate(text: String, direction: TranslationDirection) async throws -> String {
        guard #available(macOS 15.0, *) else {
            throw LocalTranslationClientError.systemTranslationUnavailable
        }

        return try await SystemTranslationSessionBroker.shared.translate(
            text: text,
            direction: direction
        )
    }
}
