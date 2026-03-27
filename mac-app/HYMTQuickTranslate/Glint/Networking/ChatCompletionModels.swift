import Foundation

struct ChatMessage: Codable, Equatable {
    let role: String?
    let content: String
}

struct ChatCompletionRequest: Codable, Equatable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct ChatCompletionResponse: Decodable, Equatable {
    struct Choice: Decodable, Equatable {
        let message: ChatMessage
    }

    let choices: [Choice]
}

struct ModelListResponse: Decodable, Equatable {
    struct Model: Decodable, Equatable {
        let id: String
    }

    let data: [Model]
}
