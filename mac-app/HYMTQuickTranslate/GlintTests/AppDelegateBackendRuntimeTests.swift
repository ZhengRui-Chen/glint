import XCTest
@testable import Glint

final class AppDelegateBackendRuntimeTests: XCTestCase {
    @MainActor
    func test_backend_settings_drive_initial_runtime_config() {
        let settings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.example.com")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "runtime-key"
        )

        let appDelegate = AppDelegate(
            launchCoordinator: ImmediateLaunchCoordinatorForBackendRuntimeTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendSettings: settings
        )

        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().baseURL, settings.baseURL)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().model, settings.model)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().apiKey, settings.apiKey)
    }

    @MainActor
    func test_applying_backend_settings_rebuilds_active_runtime_config() {
        let appDelegate = AppDelegate(
            launchCoordinator: ImmediateLaunchCoordinatorForBackendRuntimeTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendSettings: .default
        )
        let updatedSettings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.siliconflow.cn")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "updated-key"
        )

        appDelegate.applyBackendSettingsForTesting(updatedSettings)

        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().baseURL, updatedSettings.baseURL)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().model, updatedSettings.model)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().apiKey, updatedSettings.apiKey)
    }

    @MainActor
    func test_external_mode_disables_managed_backend_control_actions() {
        let appDelegate = AppDelegate(
            launchCoordinator: ImmediateLaunchCoordinatorForBackendRuntimeTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendSettings: BackendSettings(
                mode: .externalAPI,
                baseURL: URL(string: "https://api.example.com")!,
                model: "deepseek-ai/DeepSeek-V3",
                apiKey: "runtime-key"
            )
        )

        XCTAssertFalse(appDelegate.supportsManagedBackendControlActionsForTesting)
    }
}

private struct ImmediateLaunchCoordinatorForBackendRuntimeTests: AppLaunchCoordinating {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool {
        true
    }
}

private final class NoopHotkeyMonitor: GlobalHotkeyMonitoring {
    let configuredShortcut = GlobalHotkeyShortcut.default
    let isRunning = true

    func start() -> Bool {
        true
    }

    func stop() {}

    func reload(shortcut: GlobalHotkeyShortcut) -> Bool {
        true
    }
}
