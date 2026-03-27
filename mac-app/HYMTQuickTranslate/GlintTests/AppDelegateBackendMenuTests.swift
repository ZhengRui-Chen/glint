import AppKit
import XCTest
@testable import Glint

final class AppDelegateBackendMenuTests: XCTestCase {
    @MainActor
    func test_start_service_transitions_menu_to_starting_through_real_wiring() async throws {
        let controlService = BlockingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.unreachable],
            processResults: [true],
            controlService: controlService
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        try triggerMenuItem(titled: L10n.startService, in: menu)

        _ = await waitForMenuItem(titled: L10n.serviceStatusStarting, in: menu)
        let actions = await waitForRecordedActions(from: controlService)
        XCTAssertEqual(actions, [.start])
    }

    @MainActor
    func test_stop_service_disables_translation_entries_through_real_wiring() async throws {
        let controlService = BlockingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true],
            controlService: controlService
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
        try triggerMenuItem(titled: L10n.refreshStatus, in: menu)
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        try triggerMenuItem(titled: L10n.stopService, in: menu)

        let selectionItem = await waitForMenuItem(titled: L10n.translateSelection, in: menu)
        let clipboardItem = await waitForMenuItem(titled: L10n.translateClipboard, in: menu)
        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        let actions = await waitForRecordedActions(from: controlService)
        XCTAssertEqual(actions, [.stop])
    }

    @MainActor
    func test_restart_service_disables_conflicting_actions_while_starting_through_real_wiring() async throws {
        let controlService = BlockingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable],
            processResults: [true, true],
            controlService: controlService
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
        try triggerMenuItem(titled: L10n.refreshStatus, in: menu)
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        try triggerMenuItem(titled: L10n.restartService, in: menu)

        let startItem = await waitForMenuItem(titled: L10n.startService, in: menu)
        let stopItem = await waitForMenuItem(titled: L10n.stopService, in: menu)
        let restartItem = await waitForMenuItem(titled: L10n.restartService, in: menu)
        let refreshItem = await waitForMenuItem(titled: L10n.refreshStatus, in: menu)
        XCTAssertFalse(startItem.isEnabled)
        XCTAssertTrue(stopItem.isEnabled)
        XCTAssertFalse(restartItem.isEnabled)
        XCTAssertFalse(refreshItem.isEnabled)
        let actions = await waitForRecordedActions(from: controlService)
        XCTAssertEqual(actions, [.restart])
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
            backendControlService: BlockingBackendControlService(),
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    @MainActor
    func test_refresh_status_triggers_explicit_backend_refresh() async throws {
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
            backendControlService: BlockingBackendControlService(),
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        try triggerMenuItem(titled: L10n.refreshStatus, in: menu)

        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    @MainActor
    func test_applying_changed_backend_settings_triggers_explicit_backend_refresh() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let processChecker = SequencedBackendProcessChecker(results: [false, false])
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
            backendControlService: BlockingBackendControlService()
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        appDelegate.applyBackendSettingsForTesting(
            BackendSettings(
                mode: .externalAPI,
                baseURL: URL(string: "https://api.example.com")!,
                model: "deepseek-ai/DeepSeek-V3",
                apiKey: "runtime-key"
            )
        )

        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 1)
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
            backendControlService: BlockingBackendControlService()
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        controller.menuNeedsUpdate(menu)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(menu.items.first?.title, BackendStatusSnapshot.notChecked().headline)
    }

    @MainActor
    func test_backend_menu_keeps_keyboard_shortcuts_entry_and_hides_inline_recording_items() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let processChecker = SequencedBackendProcessChecker(results: [true, true])
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
            backendControlService: BlockingBackendControlService(),
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        let keyboardShortcutsItem = await waitForMenuItem(titled: L10n.keyboardShortcuts, in: menu)
        let selectionItem = await waitForMenuItem(titled: L10n.translateSelection, in: menu)
        let clipboardItem = await waitForMenuItem(titled: L10n.translateClipboard, in: menu)
        let ocrItem = await waitForMenuItem(titled: L10n.translateOCRArea, in: menu)

        XCTAssertFalse(selectionItem.isEnabled)
        XCTAssertFalse(clipboardItem.isEnabled)
        XCTAssertFalse(ocrItem.isEnabled)
        XCTAssertTrue(keyboardShortcutsItem.isEnabled)
        XCTAssertNil(menu.items.first {
            $0.title == "\(L10n.shortcutTargetSelection) Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)"
        })
        XCTAssertNil(menu.items.first {
            $0.title == "\(L10n.shortcutTargetClipboard) Shortcut: \(GlobalHotkeyShortcut.default.displayName)"
        })
        XCTAssertNil(menu.items.first {
            $0.title == "\(L10n.shortcutTargetOCR) Shortcut: \(GlobalHotkeyShortcut.ocrDefault.displayName)"
        })
        XCTAssertNil(menu.items.first { $0.title == "Cancel Shortcut Recording" })
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    @MainActor
    func test_translate_actions_do_not_trigger_separate_backend_refresh() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable])
        let processChecker = SequencedBackendProcessChecker(results: [true])
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
            backendControlService: BlockingBackendControlService()
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        try triggerMenuItem(titled: L10n.refreshStatus, in: menu)
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)
        let callCountAfterRefresh = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCountAfterRefresh, 1)

        try triggerMenuItem(titled: L10n.translateClipboard, in: menu)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let callCountAfterTranslation = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCountAfterTranslation, 1)
    }

    @MainActor
    func test_external_api_mode_refresh_does_not_rely_on_local_process_checks() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.unreachable])
        let processChecker = ExplodingBackendProcessChecker()
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker,
            processChecker: processChecker,
            now: { Date(timeIntervalSince1970: 100) },
            checksProcessWhenAPIIsUnreachable: false
        )
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendSettings: BackendSettings(
                mode: .externalAPI,
                baseURL: URL(string: "https://api.example.com")!,
                model: "deepseek-ai/DeepSeek-V3",
                apiKey: "runtime-key"
            ),
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
        _ = await waitForMenuItem(titled: BackendStatusSnapshot.notChecked().headline, in: menu)

        try triggerMenuItem(titled: L10n.refreshStatus, in: menu)

        _ = await waitForMenuItem(titled: L10n.serviceStatusUnavailable, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 1)
    }
}

private actor BlockingBackendControlService: BackendControlServicing {
    enum Action: Equatable {
        case start
        case stop
        case restart
    }

    private(set) var actions: [Action] = []

    func start() async throws {
        actions.append(.start)
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }

    func stop() async throws {
        actions.append(.stop)
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }

    func restart() async throws {
        actions.append(.restart)
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }

    func recordedActions() -> [Action] {
        actions
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
    private var action: (() -> Void)?
    private(set) var scheduleCallCount = 0

    func schedule(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any BackendRefreshControlling {
        scheduleCallCount += 1
        self.action = action
        return TestBackendRefreshTimer()
    }

    func fire() throws {
        let action = try XCTUnwrap(action)
        action()
    }
}

private struct TestBackendRefreshTimer: BackendRefreshControlling {
    func invalidate() {}
}

private actor ExplodingBackendProcessChecker: BackendProcessChecking {
    func isBackendProcessRunning() async throws -> Bool {
        XCTFail("External API refresh should not consult local process state")
        return false
    }
}

@MainActor
private func makeAppDelegate(
    apiResults: [BackendAPIReachability],
    processResults: [Bool],
    controlService: any BackendControlServicing
) -> AppDelegate {
    let monitor = BackendStatusMonitor(
        apiChecker: SequencedBackendAPIHealthChecker(results: apiResults),
        processChecker: SequencedBackendProcessChecker(results: processResults),
        now: { Date(timeIntervalSince1970: 100) }
    )
    return AppDelegate(
        shortcutSettings: .default,
        launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
        shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
        hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
        backendStatusMonitor: monitor,
        backendControlService: controlService
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

private func waitForRecordedActions(
    from service: BlockingBackendControlService,
    file: StaticString = #filePath,
    line: UInt = #line
) async -> [BlockingBackendControlService.Action] {
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        let actions = await service.recordedActions()
        if !actions.isEmpty {
            return actions
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        await Task.yield()
    }

    XCTFail("Timed out waiting for backend control action", file: file, line: line)
    return []
}
