import Foundation

enum AppBranding {
    static let displayName = "Glint"
}

struct AppConfig {
    let baseURL: URL
    let model: String
    let apiKey: String
    let requestTimeout: TimeInterval

    static let `default` = AppConfig(
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit",
        apiKey: "local-hy-key",
        requestTimeout: 20
    )
}
