import AppKit
import XCTest
@testable import Glint

final class AppDelegateBackendMenuTests: XCTestCase {
    @MainActor
    func test_api_settings_menu_item_presents_panel_through_real_wiring() async throws {
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable]
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
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        try triggerMenuItem(titled: L10n.apiSettings, in: menu)

        XCTAssertTrue(appDelegate.apiSettingsPanelControllerForTesting().isPanelVisibleForTesting)
    }

    @MainActor
    func test_menu_does_not_include_service_control_entries() async throws {
        let appDelegate = makeAppDelegate(
            apiResults: [.reachable]
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
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        XCTAssertNil(menu.items.first { $0.title == "Start Service" })
        XCTAssertNil(menu.items.first { $0.title == "Stop Service" })
        XCTAssertNil(menu.items.first { $0.title == "Restart Service" })
        XCTAssertNotNil(menu.items.first { $0.title == L10n.apiSettings })
    }

    @MainActor
    func test_opening_menu_triggers_refresh_path_and_updates_backend_status() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.unreachable, .reachable])
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker
        )
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            apiSettingsStore: APISettingsStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            )
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
        _ = await waitForMenuItem(titled: L10n.serviceStatusUnavailable, in: menu)

        controller.menuNeedsUpdate(menu)

        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func test_background_refresh_keeps_backend_snapshot_current() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.unreachable, .reachable])
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker
        )
        let scheduler = TestBackendRefreshScheduler()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            apiSettingsStore: APISettingsStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            ),
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
        _ = await waitForMenuItem(titled: L10n.serviceStatusUnavailable, in: menu)

        try scheduler.fire()

        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func test_backend_refresh_exposes_api_settings_and_keyboard_shortcuts_entries() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable, .reachable])
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker
        )
        let scheduler = TestBackendRefreshScheduler()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            apiSettingsStore: APISettingsStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            ),
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
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        try scheduler.fire()
        _ = await waitForMenuItem(titled: L10n.serviceStatusAvailable, in: menu)

        let apiSettingsItem = await waitForMenuItem(titled: L10n.apiSettings, in: menu)
        let keyboardShortcutsItem = await waitForMenuItem(titled: L10n.keyboardShortcuts, in: menu)
        let selectionItem = await waitForMenuItem(titled: L10n.translateSelection, in: menu)
        let clipboardItem = await waitForMenuItem(titled: L10n.translateClipboard, in: menu)
        let ocrItem = await waitForMenuItem(titled: L10n.translateOCRArea, in: menu)

        XCTAssertTrue(selectionItem.isEnabled)
        XCTAssertTrue(clipboardItem.isEnabled)
        XCTAssertTrue(ocrItem.isEnabled)
        XCTAssertTrue(apiSettingsItem.isEnabled)
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
    }

    @MainActor
    func test_older_backend_refresh_result_does_not_override_newer_snapshot() async throws {
        let apiChecker = ControlledBackendAPIHealthChecker()
        let monitor = BackendStatusMonitor(
            apiChecker: apiChecker
        )
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
            backendStatusMonitor: monitor,
            apiSettingsStore: APISettingsStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            )
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

        let firstRequest = await apiChecker.waitForRequest(number: 1)
        controller.menuNeedsUpdate(menu)
        let secondRequest = await apiChecker.waitForRequest(number: 2)

        await apiChecker.resolve(request: secondRequest, with: .unreachable)
        _ = await waitForMenuItem(titled: L10n.serviceStatusUnavailable, in: menu)

        await apiChecker.resolve(request: firstRequest, with: .reachable)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(menu.items.first?.title, L10n.serviceStatusUnavailable)
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

private actor ControlledBackendAPIHealthChecker: BackendAPIHealthChecking {
    private struct PendingRequest {
        let id: Int
        let continuation: CheckedContinuation<BackendAPIReachability, Error>
    }

    private var nextID = 0
    private var pendingRequests: [PendingRequest] = []

    func checkAPIReachability() async throws -> BackendAPIReachability {
        let id = nextID
        nextID += 1

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests.append(
                PendingRequest(id: id, continuation: continuation)
            )
        }
    }

    func waitForRequest(number requestNumber: Int) async -> Int {
        let expectedCount = requestNumber
        while pendingRequests.count < expectedCount {
            await Task.yield()
        }
        return pendingRequests[requestNumber - 1].id
    }

    func resolve(
        request requestID: Int,
        with result: BackendAPIReachability
    ) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == requestID }) else {
            return
        }
        let pendingRequest = pendingRequests.remove(at: index)
        pendingRequest.continuation.resume(returning: result)
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

    func schedule(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any BackendRefreshControlling {
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

@MainActor
private func makeAppDelegate(
    apiResults: [BackendAPIReachability]
) -> AppDelegate {
    let monitor = BackendStatusMonitor(
        apiChecker: SequencedBackendAPIHealthChecker(results: apiResults)
    )
    return AppDelegate(
        shortcutSettings: .default,
        launchCoordinator: ImmediateLaunchCoordinatorForBackendMenuTests(),
        shortcutRecorderUserDefaults: UserDefaults(suiteName: UUID().uuidString)!,
        hotkeyMonitorFactory: { _, _, _ in NoopHotkeyMonitor() },
        backendStatusMonitor: monitor,
        apiSettingsStore: APISettingsStore(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
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
