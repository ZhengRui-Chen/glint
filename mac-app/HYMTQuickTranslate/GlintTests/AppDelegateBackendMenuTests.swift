import AppKit
import XCTest
@testable import Glint

final class AppDelegateBackendMenuTests: XCTestCase {
    @MainActor
    func test_start_service_transitions_menu_to_starting_through_real_wiring() async throws {
        let controlService = BlockingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.unreachable],
            processResults: [false],
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
        _ = await waitForMenuItem(titled: "Service Status: Unavailable", in: menu)

        try triggerMenuItem(titled: "Start Service", in: menu)

        _ = await waitForMenuItem(titled: "Service Status: Starting", in: menu)
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
        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)

        try triggerMenuItem(titled: "Stop Service", in: menu)

        let selectionItem = await waitForMenuItem(titled: "Translate Selection", in: menu)
        let clipboardItem = await waitForMenuItem(titled: "Translate Clipboard", in: menu)
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
        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)

        try triggerMenuItem(titled: "Restart Service", in: menu)

        let startItem = await waitForMenuItem(titled: "Start Service", in: menu)
        let stopItem = await waitForMenuItem(titled: "Stop Service", in: menu)
        let restartItem = await waitForMenuItem(titled: "Restart Service", in: menu)
        let refreshItem = await waitForMenuItem(titled: "Refresh Status", in: menu)
        XCTAssertFalse(startItem.isEnabled)
        XCTAssertTrue(stopItem.isEnabled)
        XCTAssertFalse(restartItem.isEnabled)
        XCTAssertFalse(refreshItem.isEnabled)
        let actions = await waitForRecordedActions(from: controlService)
        XCTAssertEqual(actions, [.restart])
    }

    @MainActor
    func test_opening_menu_triggers_refresh_path_and_updates_backend_status() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.unreachable, .reachable])
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
        _ = await waitForMenuItem(titled: "Service Status: Unavailable", in: menu)

        controller.menuNeedsUpdate(menu)

        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func test_background_refresh_keeps_backend_snapshot_current() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.unreachable, .reachable])
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
        _ = await waitForMenuItem(titled: "Service Status: Unavailable", in: menu)

        try scheduler.fire()

        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)
        let callCount = await apiChecker.recordedCallCount()
        XCTAssertEqual(callCount, 2)
    }

    @MainActor
    func test_backend_refresh_preserves_existing_shortcut_and_translation_items() async throws {
        let apiChecker = SequencedBackendAPIHealthChecker(results: [.reachable, .reachable])
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
        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)

        try scheduler.fire()
        _ = await waitForMenuItem(titled: "Service Status: Available", in: menu)

        let selectionItem = await waitForMenuItem(titled: "Translate Selection", in: menu)
        let clipboardItem = await waitForMenuItem(titled: "Translate Clipboard", in: menu)
        let ocrItem = await waitForMenuItem(titled: "Translate OCR Area", in: menu)
        let selectionShortcutItem = await waitForMenuItem(
            titled: "Selection Shortcut: \(GlobalHotkeyShortcut.selectionDefault.displayName)",
            in: menu
        )
        let clipboardShortcutItem = await waitForMenuItem(
            titled: "Clipboard Shortcut: \(GlobalHotkeyShortcut.default.displayName)",
            in: menu
        )
        let ocrShortcutItem = await waitForMenuItem(
            titled: "OCR Shortcut: \(GlobalHotkeyShortcut.ocrDefault.displayName)",
            in: menu
        )

        XCTAssertTrue(selectionItem.isEnabled)
        XCTAssertTrue(clipboardItem.isEnabled)
        XCTAssertTrue(ocrItem.isEnabled)
        XCTAssertTrue(selectionShortcutItem.isEnabled)
        XCTAssertTrue(clipboardShortcutItem.isEnabled)
        XCTAssertTrue(ocrShortcutItem.isEnabled)
    }

    @MainActor
    func test_older_backend_refresh_result_does_not_override_newer_snapshot() async throws {
        let apiChecker = ControlledBackendAPIHealthChecker()
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

        let firstRequest = await apiChecker.waitForRequest(number: 1)
        controller.menuNeedsUpdate(menu)
        let secondRequest = await apiChecker.waitForRequest(number: 2)

        await apiChecker.resolve(request: secondRequest, with: .unreachable)
        _ = await waitForMenuItem(titled: "Service Status: Unavailable", in: menu)

        await apiChecker.resolve(request: firstRequest, with: .reachable)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(menu.items.first?.title, "Service Status: Unavailable")
    }

    @MainActor
    func test_older_refresh_result_does_not_override_starting_state_after_start_action() async throws {
        let apiChecker = ControlledBackendAPIHealthChecker()
        let processChecker = SequencedBackendProcessChecker(results: [false])
        let controlService = BlockingBackendControlService()
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
        let firstRequest = await apiChecker.waitForRequest(number: 1)

        try triggerMenuItem(titled: "Start Service", in: menu)
        _ = await waitForMenuItem(titled: "Service Status: Starting", in: menu)

        await apiChecker.resolve(request: firstRequest, with: .reachable)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(menu.items.first?.title, "Service Status: Starting")
    }

    @MainActor
    func test_menu_refresh_does_not_override_starting_state_while_start_action_is_in_flight() async throws {
        let controlService = BlockingBackendControlService()
        let appDelegate = makeAppDelegate(
            apiResults: [.unreachable, .reachable],
            processResults: [false, false],
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
        _ = await waitForMenuItem(titled: "Service Status: Unavailable", in: menu)

        try triggerMenuItem(titled: "Start Service", in: menu)
        _ = await waitForMenuItem(titled: "Service Status: Starting", in: menu)

        controller.menuNeedsUpdate(menu)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(menu.items.first?.title, "Service Status: Starting")
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
