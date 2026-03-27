import AppKit
import XCTest
@testable import Glint

final class AppDelegateBackendMenuTests: XCTestCase {
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

private let backendMenuLabel = String(
    localized: "Backend...",
    comment: "Menu entry that opens the backend panel"
)

@MainActor
private func makeAppDelegate(
    apiResults: [BackendAPIReachability],
    processResults: [Bool],
    backendSettings: BackendSettings = .default
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
        backendSettings: backendSettings,
        backendStatusMonitor: monitor,
        backendControlService: nil
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
