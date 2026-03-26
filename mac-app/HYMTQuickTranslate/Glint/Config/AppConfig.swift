import Foundation

enum AppBranding {
    static let displayName = "Glint"
    static let menuBarIconAssetName = "MenuBarIcon"
}

struct AppConfig {
    let baseURL: URL
    let model: String
    let apiKey: String
    let requestTimeout: TimeInterval
    let backendStatusRefreshInterval: TimeInterval
    let backendAPITimeout: TimeInterval

    var backendModelsURL: URL {
        baseURL.appending(path: "/v1/models")
    }

    static let `default` = AppConfig(
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit",
        apiKey: "local-hy-key",
        requestTimeout: 20,
        backendStatusRefreshInterval: 15,
        backendAPITimeout: 5
    )
}
