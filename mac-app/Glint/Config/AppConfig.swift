import Foundation

enum AppBranding {
    static let displayName = "Glint"
    static let menuBarIconAssetName = "MenuBarIcon"
}

struct AppConfig {
    let provider: TranslationProvider
    let baseURLString: String
    let baseURL: URL
    let model: String
    let apiKey: String
    let requestTimeout: TimeInterval
    let backendAPITimeout: TimeInterval

    var backendModelsURL: URL {
        baseURL.appending(path: "/v1/models")
    }

    init(
        settings: APISettings,
        requestTimeout: TimeInterval = 20,
        backendAPITimeout: TimeInterval = 5
    ) {
        provider = settings.provider
        baseURLString = settings.baseURLString
        baseURL = URL(string: settings.baseURLString) ?? URL(string: "about:blank")!
        model = settings.model
        apiKey = settings.apiKey
        self.requestTimeout = requestTimeout
        self.backendAPITimeout = backendAPITimeout
    }

    static var `default`: AppConfig {
        AppConfig(settings: APISettingsStore().load())
    }
}
