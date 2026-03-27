import Foundation

struct APISettings: Codable, Equatable {
    var baseURLString: String
    var apiKey: String
    var model: String

    init(
        baseURLString: String = "",
        apiKey: String = "",
        model: String = ""
    ) {
        self.baseURLString = baseURLString
        self.apiKey = apiKey
        self.model = model
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
