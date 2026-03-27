import AppKit
import XCTest
@testable import Glint

final class AppDelegateBackendMenuTests: XCTestCase {
    @MainActor
    func test_done_without_changes_closes_backend_panel_without_refreshing_backend() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true],
            apiChecker: apiChecker
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendPanel = appDelegate.backendPanelControllerForTesting()

        try triggerMenuItem(titled: backendMenuLabel, in: menu)
        XCTAssertTrue(backendPanel.isPanelVisibleForTesting)

        backendPanel.requestDone()

        await waitForPanelToClose(backendPanel)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
    }

    @MainActor
    func test_done_with_changes_saves_rebuilds_runtime_refreshes_and_closes_backend_panel() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let initialSettings = BackendSettings.default
        initialSettings.save(to: defaults)

        let updatedSettings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.siliconflow.cn")!,
            model: "deepseek-ai/DeepSeek-V3",
            apiKey: "runtime-key"
        )
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true],
            backendSettings: initialSettings,
            backendSettingsUserDefaults: defaults,
            apiChecker: apiChecker
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendPanel = appDelegate.backendPanelControllerForTesting()

        try triggerMenuItem(titled: backendMenuLabel, in: menu)
        backendPanel.applyDraftSettingsForTesting(updatedSettings)
        backendPanel.requestDone()

        await waitForPanelToClose(backendPanel)
        await waitForBackendCalls(expected: 1, checker: apiChecker)

        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().baseURL, updatedSettings.baseURL)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().model, updatedSettings.model)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().apiKey, updatedSettings.apiKey)
        XCTAssertEqual(BackendSettings.load(from: defaults), updatedSettings)
    }

    @MainActor
    func test_check_backend_uses_saved_settings_without_persisting_draft_edits() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let savedSettings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.example.com")!,
            model: "saved-model",
            apiKey: "saved-key"
        )
        savedSettings.save(to: defaults)

        let draftSettings = BackendSettings(
            mode: .externalAPI,
            baseURL: URL(string: "https://api.changed.example.com")!,
            model: "draft-model",
            apiKey: "draft-key"
        )
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true],
            backendSettings: savedSettings,
            backendSettingsUserDefaults: defaults,
            apiChecker: apiChecker
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendPanel = appDelegate.backendPanelControllerForTesting()

        try triggerMenuItem(titled: backendMenuLabel, in: menu)
        backendPanel.applyDraftSettingsForTesting(draftSettings)
        backendPanel.requestCheckBackend()

        await waitForBackendCalls(expected: 1, checker: apiChecker)

        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().baseURL, savedSettings.baseURL)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().model, savedSettings.model)
        XCTAssertEqual(appDelegate.activeBackendConfigForTesting().apiKey, savedSettings.apiKey)
        XCTAssertEqual(BackendSettings.load(from: defaults), savedSettings)
        XCTAssertTrue(backendPanel.isPanelVisibleForTesting)
    }

    @MainActor
    func test_managed_local_panel_actions_invoke_backend_control_service() async throws {
        let controlService = RecordingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable, .reachable, .reachable],
            processResults: [true, true, true],
            backendSettings: .default,
            backendControlService: controlService
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendPanel = appDelegate.backendPanelControllerForTesting()

        try triggerMenuItem(titled: backendMenuLabel, in: menu)
        XCTAssertTrue(backendPanel.showsManagedControlActionsForTesting)

        backendPanel.requestStartService()
        backendPanel.requestStopService()
        backendPanel.requestRestartService()

        await waitForRecordedControlActions(expected: [.start, .stop, .restart], service: controlService)
    }

    @MainActor
    func test_launch_does_not_schedule_background_refresh_or_probe_backend() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let processChecker = SequencedBackendProcessChecker(results: [false, false])
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker,
            processChecker: processChecker,
            now: { Date(timeIntervalSince1970: 100) }
        )
        let scheduler = TestBackendRefreshScheduler()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            backendControlService: nil,
            backendRefreshScheduler: scheduler
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        _ = await waitForMenuItem(titled: backendMenuLabel, in: menu)

        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    @MainActor
    func test_opening_menu_does_not_trigger_backend_refresh() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let processChecker = SequencedBackendProcessChecker(results: [false])
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker,
            processChecker: processChecker,
            now: { Date(timeIntervalSince1970: 100) }
        )
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            backendControlService: nil
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        _ = await waitForMenuItem(titled: backendMenuLabel, in: menu)

        controller.menuNeedsUpdate(menu)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
    }

    @MainActor
    func test_backend_menu_uses_single_entry_and_keeps_translation_and_shortcuts_items() async throws {
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true]
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))

        let backendItem = await waitForMenuItem(titled: backendMenuLabel, in: menu)
        let keyboardShortcutsItem = await waitForMenuItem(titled: L10n.keyboardShortcuts, in: menu)
        let selectionItem = await waitForMenuItem(titled: L10n.translateSelection, in: menu)
        let clipboardItem = await waitForMenuItem(titled: L10n.translateClipboard, in: menu)
        let ocrItem = await waitForMenuItem(titled: L10n.translateOCRArea, in: menu)

        XCTAssertTrue(backendItem.isEnabled)
        XCTAssertTrue(keyboardShortcutsItem.isEnabled)
        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        XCTAssertFalse(ocrItem.isEnabled)

        XCTAssertNil(menu.items.first { $0.title == BackendStatusSnapshot.notChecked().headline })
        XCTAssertNil(menu.items.first { $0.title == BackendStatusSnapshot.notChecked().detail })
        XCTAssertNil(menu.items.first { $0.title == L10n.startService })
        XCTAssertNil(menu.items.first { $0.title == L10n.stopService })
        XCTAssertNil(menu.items.first { $0.title == L10n.restartService })
        XCTAssertNil(menu.items.first { $0.title == L10n.refreshStatus })
    }

    @MainActor
    func test_selecting_backend_menu_item_opens_backend_panel() async throws {
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true]
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let controller = try XCTUnwrap(reflectedStatusBarController(from: appDelegate))
        let menu = try XCTUnwrap(reflectedMenu(from: controller))
        let backendPanel = appDelegate.backendPanelControllerForTesting()
        XCTAssertFalse(backendPanel.isPanelVisibleForTesting)

        try triggerMenuItem(titled: backendMenuLabel, in: menu)

        XCTAssertTrue(backendPanel.isPanelVisibleForTesting)
        backendPanel.closePanel()
    }

}

private actor SequencedBackendAPIHealthChecker: BackendAPIHealthChecking {
    private let results: [BackendAPIReachability]
    private var index = 0
    private(set) var callCount = 0

    init(results: [BackendAPIReachability]) {
        self.results = results
    }

    func checkAPIReachability() async throws -> BackendAPIReachability {
        callCount += 1
        let resolvedIndex = min(index, results.count - 1)
        defer { index += 1 }
        return results[resolvedIndex]
    }

    func recordedCallCount() -> Int {
        callCount
    }
}

private actor SequencedBackendProcessChecker: BackendProcessChecking {
    private let results: [Bool]
    private var index = 0

    init(results: [Bool]) {
        self.results = results
    }

    func isBackendProcessRunning() async throws -> Bool {
        let resolvedIndex = min(index, results.count - 1)
        defer { index += 1 }
        return results[resolvedIndex]
    }
}

private struct ImmediateLaunchCoordinatorForBackendMenuTests: AppLaunchCoordinating {
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

@MainActor
private final class TestBackendRefreshScheduler: BackendRefreshScheduling {
    private(set) var scheduleCallCount = 0

    func schedule(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any BackendRefreshControlling {
        scheduleCallCount += 1
        return TestBackendRefreshTimer()
    }
}

private struct TestBackendRefreshTimer: BackendRefreshControlling {
    func invalidate() {}
}

private actor RecordingBackendControlService: BackendControlServicing {
    enum Call: Equatable {
        case start
        case stop
        case restart
    }

    private var calls: [Call] = []

    func start() async throws {
        calls.append(.start)
    }

    func stop() async throws {
        calls.append(.stop)
    }

    func restart() async throws {
        calls.append(.restart)
    }

    func recordedCalls() -> [Call] {
        calls
    }
}

private let backendMenuLabel = L10n.backendPanelMenuItem

@MainActor
private func makeAppDelegate(
    apiResults: [BackendAPIReachability],
    processResults: [Bool],
    backendSettings: BackendSettings = .default,
    backendSettingsUserDefaults: UserDefaults = .standard,
    apiChecker: SequencedBackendAPIHealthChecker? = nil,
    backendControlService: (any BackendControlServicing)? = nil
) -> AppDelegate {
    let monitor = BackendStatusMonitor(
        apiChecker: apiChecker ?? SequencedBackendAPIHealthChecker(results: apiResults),
        processChecker: SequencedBackendProcessChecker(results: processResults),
        now: { Date(timeIntervalSince1970: 100) }
    )
    return AppDelegate(
        shortcutSettings: .default,
        launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
        backendSettingsUserDefaults: backendSettingsUserDefaults,
        shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
        hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
        backendSettings: backendSettings,
        backendStatusMonitor: monitor,
        backendControlService: backendControlService
    )
}

@MainActor
private func waitForMenuItem(
    titled title: String,
    in menu: NSMenu,
    file: StaticString = #filePath,
    line: UInt = #line
) async -> NSMenuItem {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if let item = menu.items.first(where: { $0.title == title }) {
            return item
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        await Task.yield()
    }

    XCTFail("Timed out waiting for menu item \(title)", file: file, line: line)
    return NSMenuItem()
}

@MainActor
private func waitForPanelToClose(
    _ backendPanel: BackendPanelController,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if !backendPanel.isPanelVisibleForTesting {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    XCTFail("Timed out waiting for backend panel to close", file: file, line: line)
}

private func waitForBackendCalls(
    expected: Int,
    checker: SequencedBackendAPIHealthChecker,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if await checker.recordedCallCount() == expected {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    XCTFail("Timed out waiting for backend refresh call count \(expected)", file: file, line: line)
}

private func waitForRecordedControlActions(
    expected: [RecordingBackendControlService.Call],
    service: RecordingBackendControlService,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if await service.recordedCalls() == expected {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    XCTFail("Timed out waiting for backend control actions \(expected)", file: file, line: line)
}

@MainActor
private func triggerMenuItem(
    titled title: String,
    in menu: NSMenu,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let item = try XCTUnwrap(
        menu.items.first(where: { $0.title == title }),
        file: file,
        line: line
    )
    let action = try XCTUnwrap(item.action, file: file, line: line)
    let didSendAction = NSApp.sendAction(action, to: item.target, from: item)
    XCTAssertTrue(didSendAction, file: file, line: line)
}

private func reflectedStatusBarController(from appDelegate: AppDelegate) -> StatusBarController? {
    Mirror(reflecting: appDelegate).children
        .first { $0.label == "statusBarController" }?
        .value as? StatusBarController
}

private func reflectedMenu(from controller: StatusBarController) -> NSMenu? {
    Mirror(reflecting: controller).children
        .first { $0.label == "menu" }?
        .value as? NSMenu
}
