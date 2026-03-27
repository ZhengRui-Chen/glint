import Foundation

@MainActor
final class BackendPanelViewModel: ObservableObject {
    @Published private(set) var savedSettings: BackendSettings
    @Published private(set) var draftSettings: BackendSettings
    @Published private(set) var statusSnapshot: BackendStatusSnapshot
    @Published private(set) var baseURLText: String
    @Published private(set) var modelText: String
    @Published private(set) var apiKeyText: String

    init(
        savedSettings: BackendSettings,
        statusSnapshot: BackendStatusSnapshot
    ) {
        self.savedSettings = savedSettings
        self.draftSettings = savedSettings
        self.statusSnapshot = statusSnapshot
        self.baseURLText = savedSettings.baseURL.absoluteString
        self.modelText = savedSettings.model
        self.apiKeyText = savedSettings.apiKey
    }

    var hasChanges: Bool {
        draftSettings != savedSettings
            || baseURLText != savedSettings.baseURL.absoluteString
            || modelText != savedSettings.model
            || apiKeyText != savedSettings.apiKey
    }

    var showsManagedControlActions: Bool {
        false
    }

    var statusHeadline: String {
        statusSnapshot.headline
    }

    var statusDetail: String {
        statusSnapshot.detail
    }

    func prepareForPresentation(
        savedSettings: BackendSettings,
        statusSnapshot: BackendStatusSnapshot
    ) {
        self.statusSnapshot = statusSnapshot
        applySavedSettings(savedSettings)
    }

    func updateStatusSnapshot(_ statusSnapshot: BackendStatusSnapshot) {
        self.statusSnapshot = statusSnapshot
    }

    func applySavedSettings(_ settings: BackendSettings) {
        savedSettings = settings
        applyDraftSettings(settings)
    }

    func updateBaseURL(_ baseURLText: String) {
        self.baseURLText = baseURLText
        guard let url = URL(string: baseURLText) else {
            return
        }

        replaceDraftSettings(
            BackendSettings(
                baseURL: url,
                model: draftSettings.model,
                apiKey: draftSettings.apiKey
            )
        )
    }

    func updateModel(_ model: String) {
        replaceDraftSettings(
            BackendSettings(
                baseURL: draftSettings.baseURL,
                model: model,
                apiKey: draftSettings.apiKey
            )
        )
    }

    func updateAPIKey(_ apiKey: String) {
        replaceDraftSettings(
            BackendSettings(
                baseURL: draftSettings.baseURL,
                model: draftSettings.model,
                apiKey: apiKey
            )
        )
    }

    func resetDraftToDefaults() {
        applyDraftSettings(.default)
    }

    func applyDraftSettingsForTesting(_ settings: BackendSettings) {
        applyDraftSettings(settings)
    }

    private func replaceDraftSettings(_ settings: BackendSettings) {
        draftSettings = settings
        baseURLText = settings.baseURL.absoluteString
        modelText = settings.model
        apiKeyText = settings.apiKey
    }

    private func applyDraftSettings(_ settings: BackendSettings) {
        draftSettings = settings
        baseURLText = settings.baseURL.absoluteString
        modelText = settings.model
        apiKeyText = settings.apiKey
    }
}
