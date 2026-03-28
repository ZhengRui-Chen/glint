import XCTest
@testable import Glint

final class APISettingsStoreTests: XCTestCase {
    func test_store_returns_empty_settings_when_nothing_has_been_saved() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let store = APISettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(store.load(), APISettings())
    }

    func test_store_round_trips_runtime_api_settings() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let store = APISettingsStore(userDefaults: userDefaults)
        let settings = APISettings(
            provider: .customAPI,
            baseURLString: "https://example.invalid/v1",
            apiKey: "test-key",
            model: "gpt-test"
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func test_store_round_trips_system_translation_provider() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let store = APISettingsStore(userDefaults: userDefaults)
        let settings = APISettings(provider: .system)

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func test_store_loads_legacy_saved_settings_as_custom_api_provider() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let legacyPayload = """
        {
          "baseURLString": "https://legacy.invalid/v1",
          "apiKey": "legacy-key",
          "model": "legacy-model"
        }
        """.data(using: .utf8)!
        userDefaults.set(legacyPayload, forKey: "apiSettings")

        let store = APISettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(
            store.load(),
            APISettings(
                provider: .customAPI,
                baseURLString: "https://legacy.invalid/v1",
                apiKey: "legacy-key",
                model: "legacy-model"
            )
        )
    }
}
