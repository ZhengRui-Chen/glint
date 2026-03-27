import Foundation

enum BackendMode: String, Codable, Equatable {
    case managedLocal
    case externalAPI
}

struct BackendSettings: Codable, Equatable {
    let mode: BackendMode
    let baseURL: URL
    let model: String
    let apiKey: String

    static let `default` = BackendSettings(
        mode: .managedLocal,
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit",
        apiKey: "local-hy-key"
    )

    private static let userDefaultsKey = "backendSettings"

    init(
        mode: BackendMode,
        baseURL: URL,
        model: String,
        apiKey: String
    ) {
        self.mode = mode
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
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
