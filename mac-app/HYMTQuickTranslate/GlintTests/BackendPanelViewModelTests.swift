import XCTest
@testable import Glint

@MainActor
final class BackendPanelViewModelTests: XCTestCase {
    func test_draft_state_mirrors_saved_settings_on_open() {
        let settings = BackendSettings(
            baseURL: URL(string: "https://api.example.com")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "runtime-key"
        )

        let viewModel = BackendPanelViewModel(
            savedSettings: settings,
            statusSnapshot: .notChecked()
        )

        XCTAssertEqual(viewModel.savedSettings, settings)
        XCTAssertEqual(viewModel.draftSettings, settings)
        XCTAssertFalse(viewModel.hasChanges)
    }

    func test_editing_draft_settings_marks_view_model_as_changed() {
        let viewModel = BackendPanelViewModel(
            savedSettings: .default,
            statusSnapshot: .notChecked()
        )

        viewModel.updateModel("deepseek-ai/DeepSeek-V3")

        XCTAssertTrue(viewModel.hasChanges)
        XCTAssertEqual(viewModel.draftSettings.model, "deepseek-ai/DeepSeek-V3")
        XCTAssertEqual(viewModel.savedSettings.model, BackendSettings.default.model)
    }

    func test_reset_only_updates_draft_state_until_save() {
        let savedSettings = BackendSettings(
            baseURL: URL(string: "https://api.example.com")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "runtime-key"
        )
        let viewModel = BackendPanelViewModel(
            savedSettings: savedSettings,
            statusSnapshot: .notChecked()
        )

        viewModel.resetDraftToDefaults()

        XCTAssertEqual(viewModel.savedSettings, savedSettings)
        XCTAssertEqual(viewModel.draftSettings, BackendSettings.default)
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_backend_panel_never_shows_managed_control_actions() {
        let viewModel = BackendPanelViewModel(
            savedSettings: .default,
            statusSnapshot: .notChecked()
        )

        XCTAssertFalse(viewModel.showsManagedControlActions)
    }
}
