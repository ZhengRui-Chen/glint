import Foundation

struct AppConfig {
    let baseURL: URL
    let model: String

    static let `default` = AppConfig(
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit"
    )
}
