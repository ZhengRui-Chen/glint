import XCTest
@testable import Glint

final class BackendSettingsTests: XCTestCase {
    func test_load_falls_back_to_default_settings_when_no_value_saved() {
        let userDefaults = makeUserDefaults()

        XCTAssertEqual(BackendSettings.load(from: userDefaults), .default)
    }

    func test_save_and_reload_round_trips_fields() {
        let userDefaults = makeUserDefaults()
        let settings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.example.com")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "test-key"
        )

        settings.save(to: userDefaults)

        XCTAssertEqual(BackendSettings.load(from: userDefaults), settings)
    }

    func test_mode_round_trips_for_each_backend_mode() {
        let userDefaults = makeUserDefaults()
        let localSettings = BackendSettings(
            mode: .managedLocal,
            baseURL: URL(string: "http://127.0.0.1:8001")!,
            model: "HY-MT1.5-1.8B-4bit",
            apiKey: "local-hy-key"
        )
        let remoteSettings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.siliconflow.cn")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "remote-key"
        )

        localSettings.save(to: userDefaults)
        XCTAssertEqual(BackendSettings.load(from: userDefaults).mode, .managedLocal)

        remoteSettings.save(to: userDefaults)
        XCTAssertEqual(BackendSettings.load(from: userDefaults).mode, .externalAPI)
    }

    func test_reset_to_defaults_returns_default_settings() {
        let settings = BackendSettings(
            mode: .externalAPI,
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
