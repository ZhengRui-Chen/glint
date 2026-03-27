import XCTest
@testable import Glint

final class BackendSettingsTests: XCTestCase {
    private static let userDefaultsKey = "backendSettings"

    func test_load_falls_back_to_default_settings_when_no_value_saved() {
        let userDefaults = makeUserDefaults()

        XCTAssertEqual(BackendSettings.load(from: userDefaults), .default)
    }

    func test_save_and_reload_round_trips_fields() {
        let userDefaults = makeUserDefaults()
        let settings = BackendSettings(
            baseURL: URL(string: "https://api.example.com")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "test-key"
        )

        settings.save(to: userDefaults)

        XCTAssertEqual(BackendSettings.load(from: userDefaults), settings)
    }

    func test_load_preserves_api_fields_from_legacy_mode_based_payload() throws {
        let userDefaults = makeUserDefaults()
        let legacySettings = LegacyBackendSettingsV1(
            mode: "externalAPI",
            baseURL: URL(string: "https://api.siliconflow.cn")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "remote-key"
        )
        let legacyData = try JSONEncoder().encode(legacySettings)
        userDefaults.set(legacyData, forKey: Self.userDefaultsKey)

        XCTAssertEqual(
            BackendSettings.load(from: userDefaults),
            BackendSettings(
                baseURL: legacySettings.baseURL,
                model: legacySettings.model,
                apiKey: legacySettings.apiKey
            )
        )
    }

    func test_reset_to_defaults_returns_default_settings() {
        let settings = BackendSettings(
            baseURL: URL(string: "https://api.example.com")!,
            model: "custom-model",
            apiKey: "custom-key"
        )

        XCTAssertEqual(settings.resetToDefaults(), .default)
    }

    private func makeUserDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
        let suiteName = "BackendSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        XCTAssertNotNil(userDefaults, file: file, line: line)
        return userDefaults ?? .standard
    }
}

private struct LegacyBackendSettingsV1: Codable {
    let mode: String
    let baseURL: URL
    let model: String
    let apiKey: String
}
