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
            baseURLString: "https://example.invalid/v1",
            apiKey: "test-key",
            model: "gpt-test"
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }
}
