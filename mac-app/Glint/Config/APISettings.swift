import Foundation

enum TranslationProvider: String, CaseIterable, Codable, Equatable, Sendable {
    case customAPI
    case system
}

struct APISettings: Codable, Equatable {
    var provider: TranslationProvider
    var baseURLString: String
    var apiKey: String
    var model: String

    init(
        provider: TranslationProvider = .customAPI,
        baseURLString: String = "",
        apiKey: String = "",
        model: String = ""
    ) {
        self.provider = provider
        self.baseURLString = baseURLString
        self.apiKey = apiKey
        self.model = model
    }

    private enum CodingKeys: String, CodingKey {
        case provider
        case baseURLString
        case apiKey
        case model
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decodeIfPresent(TranslationProvider.self, forKey: .provider) ?? .customAPI
        baseURLString = try container.decodeIfPresent(String.self, forKey: .baseURLString) ?? ""
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
    }
}

struct APISettingsStore {
    private static let userDefaultsKey = "apiSettings"

    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> APISettings {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey),
              let settings = try? JSONDecoder().decode(APISettings.self, from: data) else {
            return APISettings()
        }
        return settings
    }

    func save(_ settings: APISettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
