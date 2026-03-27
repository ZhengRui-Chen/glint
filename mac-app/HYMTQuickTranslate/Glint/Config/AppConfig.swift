import Foundation

enum AppBranding {
    static let displayName = "Glint"
    static let menuBarIconAssetName = "MenuBarIcon"
}

struct AppConfig {
    let baseURLString: String
    let baseURL: URL
    let model: String
    let apiKey: String
    let requestTimeout: TimeInterval
    let backendStatusRefreshInterval: TimeInterval
    let backendAPITimeout: TimeInterval

    var backendModelsURL: URL {
        baseURL.appending(path: "/v1/models")
    }

    init(
        settings: APISettings,
        requestTimeout: TimeInterval = 20,
        backendStatusRefreshInterval: TimeInterval = 15,
        backendAPITimeout: TimeInterval = 5
    ) {
        baseURLString = settings.baseURLString
        baseURL = URL(string: settings.baseURLString) ?? URL(string: "about:blank")!
        model = settings.model
        apiKey = settings.apiKey
        self.requestTimeout = requestTimeout
        self.backendStatusRefreshInterval = backendStatusRefreshInterval
        self.backendAPITimeout = backendAPITimeout
    }

    static var `default`: AppConfig {
        AppConfig(settings: APISettingsStore().load())
    }
}
