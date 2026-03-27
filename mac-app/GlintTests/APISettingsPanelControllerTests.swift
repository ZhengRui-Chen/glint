import XCTest
@testable import Glint

@MainActor
final class APISettingsPanelControllerTests: XCTestCase {
    func test_view_state_syncs_draft_settings_and_model_options() {
        let state = APISettingsPanelViewState(
            settings: APISettings(
                baseURLString: "https://example.invalid/v1",
                apiKey: "first-key",
                model: "first-model"
            ),
            availableModels: ["first-model"]
        )

        XCTAssertEqual(state.baseURLString, "https://example.invalid/v1")
        XCTAssertEqual(state.apiKey, "first-key")
        XCTAssertEqual(state.model, "first-model")
        XCTAssertEqual(state.availableModels, ["first-model"])
        XCTAssertFalse(state.isRefreshingModels)

        state.update(
            settings: APISettings(
                baseURLString: "https://other.invalid/v1",
                apiKey: "second-key",
                model: "second-model"
            ),
            availableModels: ["a-model", "z-model"]
        )

        XCTAssertEqual(state.baseURLString, "https://other.invalid/v1")
        XCTAssertEqual(state.apiKey, "second-key")
        XCTAssertEqual(state.model, "second-model")
        XCTAssertEqual(state.availableModels, ["a-model", "z-model"])
    }

    func test_controller_saves_current_draft_and_notifies_callback() {
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = APISettingsStore(userDefaults: userDefaults)
        var didSave = false
        let controller = APISettingsPanelController(
            store: store,
            makeDiscoveryClient: { _ in FailingModelDiscoveryClient() },
            onSave: { didSave = true }
        )

        controller.updateDraftForTesting(
            APISettings(
                baseURLString: "https://saved.invalid/v1",
                apiKey: "saved-key",
                model: "saved-model"
            )
        )
        controller.requestSave()

        XCTAssertEqual(
            store.load(),
            APISettings(
                baseURLString: "https://saved.invalid/v1",
                apiKey: "saved-key",
                model: "saved-model"
            )
        )
        XCTAssertTrue(didSave)
    }

    func test_controller_refreshes_models_using_current_draft_settings() async throws {
        let store = APISettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let recorder = ModelDiscoveryFactoryRecorder()
        let controller = APISettingsPanelController(
            store: store,
            makeDiscoveryClient: recorder.makeClient(settings:)
        )

        controller.updateDraftForTesting(
            APISettings(
                baseURLString: "https://draft.invalid/v1",
                apiKey: "draft-key",
                model: "manual-model"
            )
        )

        try await controller.refreshModels()

        XCTAssertEqual(
            recorder.receivedSettings,
            [
                APISettings(
                    baseURLString: "https://draft.invalid/v1",
                    apiKey: "draft-key",
                    model: "manual-model"
                )
            ]
        )
        XCTAssertEqual(
            controller.testingSnapshot.availableModels,
            ["a-model", "m-model", "z-model"]
        )
        XCTAssertNil(controller.testingSnapshot.statusMessage)
    }
}

private struct FailingModelDiscoveryClient: ModelDiscoveryFetching {
    func fetchModels() async throws -> [String] {
        throw URLError(.cannotFindHost)
    }
}

@MainActor
private final class ModelDiscoveryFactoryRecorder {
    private(set) var receivedSettings: [APISettings] = []

    func makeClient(settings: APISettings) -> any ModelDiscoveryFetching {
        receivedSettings.append(settings)
        return StubModelDiscoveryClient()
    }
}

private struct StubModelDiscoveryClient: ModelDiscoveryFetching {
    func fetchModels() async throws -> [String] {
        ["a-model", "m-model", "z-model"]
    }
}
