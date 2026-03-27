import Foundation

struct BackendSettings: Codable, Equatable {
    let baseURL: URL
    let model: String
    let apiKey: String

    static let `default` = BackendSettings(
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit",
        apiKey: "local-hy-key"
    )

    private static let userDefaultsKey = "backendSettings"

    init(
        baseURL: URL,
        model: String,
        apiKey: String
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }

    enum CodingKeys: String, CodingKey {
        case baseURL
        case model
        case apiKey
        case mode
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        apiKey = try container.decode(String.self, forKey: .apiKey)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(apiKey, forKey: .apiKey)
    }

    static func load(from userDefaults: UserDefaults = .standard) -> BackendSettings {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(BackendSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(to userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func resetToDefaults() -> BackendSettings {
        .default
    }
}
