import XCTest
@testable import Glint

@MainActor
final class APISettingsPanelControllerTests: XCTestCase {
    func test_view_state_syncs_draft_settings_and_model_options() {
        let state = APISettingsPanelViewState(
            settings: APISettings(
                provider: .customAPI,
                baseURLString: "https://example.invalid/v1",
                apiKey: "first-key",
                model: "first-model"
            ),
            availableModels: ["first-model"]
        )

        XCTAssertEqual(state.provider, .customAPI)
        XCTAssertEqual(state.baseURLString, "https://example.invalid/v1")
        XCTAssertEqual(state.apiKey, "first-key")
        XCTAssertEqual(state.model, "first-model")
        XCTAssertEqual(state.availableModels, ["first-model"])
        XCTAssertFalse(state.isRefreshingModels)

        state.update(
            settings: APISettings(
                provider: .system,
                baseURLString: "https://other.invalid/v1",
                apiKey: "second-key",
                model: "second-model"
            ),
            availableModels: ["a-model", "z-model"]
        )

        XCTAssertEqual(state.provider, .system)
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
                provider: .system,
                baseURLString: "https://saved.invalid/v1",
                apiKey: "saved-key",
                model: "saved-model"
            )
        )
        controller.requestSave()

        XCTAssertEqual(
            store.load(),
            APISettings(
                provider: .system,
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
                provider: .customAPI,
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
                    provider: .customAPI,
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

    func test_controller_uses_panel_height_that_keeps_action_buttons_visible() {
        let controller = APISettingsPanelController(
            store: APISettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        )

        XCTAssertEqual(controller.testingPanelFrame.height, 420)
    }

    func test_controller_persists_selected_model_from_combo_box() async throws {
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = APISettingsStore(userDefaults: userDefaults)
        let controller = APISettingsPanelController(
            store: store,
            makeDiscoveryClient: { _ in StubModelDiscoveryClient() }
        )

        controller.updateDraftForTesting(
            APISettings(
                provider: .customAPI,
                baseURLString: "http://127.0.0.1:8001",
                apiKey: "change-me",
                model: ""
            )
        )
        try await controller.refreshModels()
        controller.show()
        try await Task.sleep(for: .milliseconds(50))

        let comboBox = try XCTUnwrap(
            controller.testingModelComboBox,
            "Expected API settings panel to contain a model combo box"
        )
        comboBox.selectItem(at: 1)
        controller.requestSave()

        XCTAssertEqual(store.load().model, "m-model")
    }

    func test_controller_does_not_refresh_models_for_system_translation_provider() async throws {
        let store = APISettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let recorder = ModelDiscoveryFactoryRecorder()
        let controller = APISettingsPanelController(
            store: store,
            makeDiscoveryClient: recorder.makeClient(settings:)
        )

        controller.updateDraftForTesting(
            APISettings(
                provider: .system,
                baseURLString: "https://ignored.invalid/v1",
                apiKey: "ignored-key",
                model: "ignored-model"
            )
        )

        let models = try await controller.refreshModels()

        XCTAssertTrue(models.isEmpty)
        XCTAssertTrue(recorder.receivedSettings.isEmpty)
    }

    func test_controller_refreshes_system_translation_availability_for_system_provider() async {
        let store = APISettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let expectedReport = SystemTranslationAvailabilityReport.make(
            enToZh: .installed,
            zhToEn: .supported
        )
        let controller = APISettingsPanelController(
            store: store,
            makeDiscoveryClient: { _ in StubModelDiscoveryClient() },
            systemTranslationAvailabilityInspector: StubSystemTranslationAvailabilityInspector(
                report: expectedReport
            )
        )

        controller.updateDraftForTesting(
            APISettings(
                provider: .system,
                baseURLString: "",
                apiKey: "",
                model: ""
            )
        )

        let report = await controller.refreshSystemTranslationAvailability()

        XCTAssertEqual(report, expectedReport)
        XCTAssertEqual(controller.testingSnapshot.systemTranslationAvailability, expectedReport)
        XCTAssertFalse(controller.testingSnapshot.isRefreshingSystemTranslationAvailability)
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

private struct StubSystemTranslationAvailabilityInspector: SystemTranslationAvailabilityInspecting {
    let report: SystemTranslationAvailabilityReport

    func availabilityReport() async -> SystemTranslationAvailabilityReport {
        report
    }
}
