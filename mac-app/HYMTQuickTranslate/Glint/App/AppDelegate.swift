import AppKit

protocol BackendRefreshControlling {
    func invalidate()
}

private final class BackendRefreshTimerTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc
    func fire() {
        action()
    }
}

@MainActor
protocol BackendRefreshScheduling {
    func schedule(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any BackendRefreshControlling
}

private struct BackendRefreshTimer: BackendRefreshControlling {
    let timer: Timer
    let target: BackendRefreshTimerTarget

    func invalidate() {
        timer.invalidate()
    }
}

@MainActor
private struct TimerBackendRefreshScheduler: BackendRefreshScheduling {
    func schedule(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> any BackendRefreshControlling {
        let target = BackendRefreshTimerTarget(action: action)
        let timer = Timer(
            timeInterval: interval,
            target: target,
            selector: #selector(BackendRefreshTimerTarget.fire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        return BackendRefreshTimer(timer: timer, target: target)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias HotkeyMonitorFactory = (
        UInt32,
        GlobalHotkeyShortcut,
        @escaping () -> Void
    ) -> GlobalHotkeyMonitoring

    private static let defaultHotkeyMonitorFactory: HotkeyMonitorFactory = {
        identifier,
        shortcut,
        onTrigger in
        GlobalHotkeyMonitor(
            identifier: identifier,
            shortcut: shortcut,
            onTrigger: onTrigger
        )
    }

    private let accessibilityPermission = AccessibilityPermission()
    private let overlayController = OverlayPanelController()
    private let workflow = TranslateClipboardWorkflow()
    private let selectionWorkflow = TranslateTextWorkflow(
        inputSource: SelectionInputSource(),
        noTextMessage: "No selected text was found.",
        permissionRequiredMessage: "Accessibility permission is not granted.",
        automationPermissionRequiredMessage: "Browser automation permission is not granted. Allow Glint to control the browser and try again.",
        unsupportedHostAppMessage: "Frontmost app does not expose selected text through Accessibility APIs.",
        rejectedTextMessage: "Selected text exceeds the maximum length."
    )
    private let overlayPlacementResolver = OverlayPlacementResolver()
    private let launchCoordinator: any AppLaunchCoordinating
    private let shortcutRecorderUserDefaults: UserDefaults
    private let hotkeyMonitorFactory: HotkeyMonitorFactory
    nonisolated(unsafe) private let backendStatusMonitor: BackendStatusMonitor
    nonisolated(unsafe) private let backendControlService: any BackendControlServicing
    private let backendRefreshScheduler: any BackendRefreshScheduling
    private var shortcutSettings: ShortcutSettings
    private lazy var shortcutRecorder = ShortcutRecorder(
        existingSettings: shortcutSettings,
        userDefaults: shortcutRecorderUserDefaults
    )
    private lazy var shortcutPanelController = ShortcutPanelController(
        shortcutSettings: shortcutSettings
    ) { [weak self] action in
        self?.handleShortcutPanelAction(action) ?? false
    }
    private var clipboardHotkeyMonitor: GlobalHotkeyMonitoring?
    private var selectionHotkeyMonitor: GlobalHotkeyMonitoring?
    private var statusBarController: StatusBarController?
    private var recordingTarget: ShortcutTarget?
    private var shortcutStatusLabel: String?
    private var backendStatus = BackendStatusSnapshot.checking()
    private var backendActionContext: BackendActionContext?
    private var isBackendControlActionInFlight = false
    private var backendRefreshGeneration = 0
    private var backendRefreshTimer: (any BackendRefreshControlling)?
    private var localShortcutRecordingMonitor: Any?
    private var globalShortcutRecordingMonitor: Any?

    override init() {
        shortcutSettings = .load()
        launchCoordinator = AppLaunchCoordinator()
        shortcutRecorderUserDefaults = .standard
        hotkeyMonitorFactory = Self.defaultHotkeyMonitorFactory
        backendStatusMonitor = BackendStatusMonitor()
        backendControlService = BackendControlService()
        backendRefreshScheduler = TimerBackendRefreshScheduler()
        super.init()
    }

    init(
        shortcutSettings: ShortcutSettings = .load(),
        launchCoordinator: any AppLaunchCoordinating = AppLaunchCoordinator(),
        shortcutRecorderUserDefaults: UserDefaults = .standard,
        hotkeyMonitorFactory: @escaping HotkeyMonitorFactory = AppDelegate.defaultHotkeyMonitorFactory,
        backendStatusMonitor: BackendStatusMonitor = BackendStatusMonitor(),
        backendControlService: any BackendControlServicing = BackendControlService(),
        backendRefreshScheduler: any BackendRefreshScheduling = TimerBackendRefreshScheduler()
    ) {
        self.shortcutSettings = shortcutSettings
        self.launchCoordinator = launchCoordinator
        self.shortcutRecorderUserDefaults = shortcutRecorderUserDefaults
        self.hotkeyMonitorFactory = hotkeyMonitorFactory
        self.backendStatusMonitor = backendStatusMonitor
        self.backendControlService = backendControlService
        self.backendRefreshScheduler = backendRefreshScheduler
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(
            onMenuWillOpen: { [weak self] in
                self?.refreshBackendStatus()
            }
        ) { [weak self] in
            self?.makeMenuBarViewModel() ?? MenuBarViewModel(
                permissionStatus: .required,
                backendStatus: .checking()
            )
        }
        startBackendRefreshTimer()
        refreshBackendStatus()
        registerHotkeysIfNeeded(immediatelyAfterLaunch: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardHotkeyMonitor?.stop()
        clipboardHotkeyMonitor = nil
        selectionHotkeyMonitor?.stop()
        selectionHotkeyMonitor = nil
        removeShortcutRecordingMonitors()
        backendRefreshTimer?.invalidate()
        backendRefreshTimer = nil
    }

    private func translateClipboard() {
        Task {
            overlayController.show(state: .loading, placement: .centered)
            let state = await workflow.handleShortcut()
            present(state, placement: .centered)
        }
    }

    private func handleSelectionTranslation() {
        let placement = overlayPlacementResolver.resolve(cursorAnchor: NSEvent.mouseLocation)
        guard accessibilityPermission.isGranted else {
            overlayController.show(
                state: .error("Accessibility permission is required for selection translation."),
                placement: placement
            )
            return
        }

        Task {
            switch await selectionWorkflow.prepare() {
            case let .translate(text):
                overlayController.show(state: .loading, placement: placement)
                let state = await selectionWorkflow.confirmTranslation(for: text)
                present(state, placement: placement)
            case let .final(state):
                present(state, placement: placement)
            }
        }
    }

    private func confirmTranslation(
        _ text: String,
        placement: OverlayPlacement = .centered
    ) {
        Task {
            overlayController.show(state: .loading, placement: placement)
            let state = await workflow.confirmTranslation(for: text)
            present(state, placement: placement)
        }
    }

    private func registerHotkeysIfNeeded(immediatelyAfterLaunch: Bool) {
        guard launchCoordinator.shouldRegisterHotkey(
            immediatelyAfterLaunch: immediatelyAfterLaunch
        ) else {
            DispatchQueue.main.async { [weak self] in
                self?.registerHotkeysIfNeeded(immediatelyAfterLaunch: false)
            }
            return
        }

        configureHotkeyMonitors()
    }

    // 所有入口都收敛到同一个面板状态机，避免多窗口分叉。
    private func present(
        _ state: OverlayViewState,
        placement: OverlayPlacement = .centered
    ) {
        switch state {
        case let .confirmLongText(text):
            overlayController.show(state: state, placement: placement) { [weak self] _ in
                self?.confirmTranslation(text, placement: placement)
            }
        default:
            overlayController.show(state: state, placement: placement)
        }
    }

    private func makeMenuBarViewModel() -> MenuBarViewModel {
        MenuBarViewModel(
            permissionStatus: accessibilityPermission.isGranted ? .granted : .required,
            backendStatus: backendStatus,
            onTranslateSelection: { [weak self] in
                self?.handleSelectionTranslation()
            },
            onTranslateClipboard: { [weak self] in
                self?.translateClipboard()
            },
            onStartService: { [weak self] in
                self?.startBackendService()
            },
            onStopService: { [weak self] in
                self?.stopBackendService()
            },
            onRestartService: { [weak self] in
                self?.restartBackendService()
            },
            onRefreshStatus: { [weak self] in
                self?.refreshBackendStatus()
            },
            onOpenShortcutPanel: { [weak self] in
                self?.openShortcutPanel()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func startBackendService() {
        invalidateInFlightBackendRefreshes()
        isBackendControlActionInFlight = true
        backendActionContext = BackendActionContext(action: .start, requestedAt: Date())
        updateBackendStatus(.starting(detail: "Backend is starting, please wait"))
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await backendControlService.start()
                isBackendControlActionInFlight = false
                refreshBackendStatus()
            } catch {
                isBackendControlActionInFlight = false
                updateBackendStatus(
                    .error(detail: "Failed to start the service"),
                    clearActionContext: true
                )
            }
        }
    }

    private func stopBackendService() {
        invalidateInFlightBackendRefreshes()
        isBackendControlActionInFlight = true
        backendActionContext = nil
        updateBackendStatus(.unavailable(detail: "Backend is currently unavailable"))
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await backendControlService.stop()
                isBackendControlActionInFlight = false
                refreshBackendStatus()
            } catch {
                isBackendControlActionInFlight = false
                updateBackendStatus(.error(detail: "Failed to stop the service"))
            }
        }
    }

    private func restartBackendService() {
        invalidateInFlightBackendRefreshes()
        isBackendControlActionInFlight = true
        backendActionContext = BackendActionContext(action: .restart, requestedAt: Date())
        updateBackendStatus(.starting(detail: "Backend is starting, please wait"))
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await backendControlService.restart()
                isBackendControlActionInFlight = false
                refreshBackendStatus()
            } catch {
                isBackendControlActionInFlight = false
                updateBackendStatus(
                    .error(detail: "Failed to restart the service"),
                    clearActionContext: true
                )
            }
        }
    }

    private func refreshBackendStatus() {
        guard !isBackendControlActionInFlight else {
            return
        }
        let refreshGeneration = nextBackendRefreshGeneration()
        updateBackendStatus(.checking())
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let snapshot = await backendStatusMonitor.refresh(actionContext: backendActionContext)
            guard shouldApplyBackendRefreshResult(for: refreshGeneration) else {
                return
            }
            updateBackendStatus(
                snapshot,
                clearActionContext: {
                    if case .starting = snapshot {
                        return false
                    }
                    return true
                }()
            )
        }
    }

    private func nextBackendRefreshGeneration() -> Int {
        backendRefreshGeneration += 1
        return backendRefreshGeneration
    }

    private func invalidateInFlightBackendRefreshes() {
        backendRefreshGeneration += 1
    }

    private func shouldApplyBackendRefreshResult(for refreshGeneration: Int) -> Bool {
        refreshGeneration == backendRefreshGeneration
    }

    private func updateBackendStatus(
        _ snapshot: BackendStatusSnapshot,
        clearActionContext: Bool = false
    ) {
        backendStatus = snapshot
        if clearActionContext {
            backendActionContext = nil
        }
        statusBarController?.refreshMenu()
    }

    private func startBackendRefreshTimer() {
        backendRefreshTimer?.invalidate()
        backendRefreshTimer = backendRefreshScheduler.schedule(
            interval: AppConfig.default.backendStatusRefreshInterval
        ) { [weak self] in
            self?.refreshBackendStatus()
        }
    }

    private func configureHotkeyMonitors() {
        if clipboardHotkeyMonitor == nil {
            clipboardHotkeyMonitor = hotkeyMonitorFactory(
                1,
                shortcutSettings.clipboardShortcut
            ) { [weak self] in
                self?.translateClipboard()
            }
        }
        startHotkeyMonitor(
            clipboardHotkeyMonitor,
            target: .clipboard,
            configuredShortcut: shortcutSettings.clipboardShortcut,
            defaultShortcut: .default
        )

        if selectionHotkeyMonitor == nil {
            selectionHotkeyMonitor = hotkeyMonitorFactory(
                2,
                shortcutSettings.selectionShortcut
            ) { [weak self] in
                self?.handleSelectionTranslation()
            }
        }
        startHotkeyMonitor(
            selectionHotkeyMonitor,
            target: .selection,
            configuredShortcut: shortcutSettings.selectionShortcut,
            defaultShortcut: .selectionDefault
        )
    }

    private func startHotkeyMonitor(
        _ monitor: GlobalHotkeyMonitoring?,
        target: ShortcutTarget,
        configuredShortcut: GlobalHotkeyShortcut,
        defaultShortcut: GlobalHotkeyShortcut
    ) {
        guard let monitor else {
            return
        }

        if monitor.start() {
            return
        }

        let targetLabel = switch target {
        case .clipboard:
            "Clipboard"
        case .selection:
            "Selection"
        }

        if configuredShortcut != defaultShortcut,
           monitor.reload(shortcut: defaultShortcut) {
            persist(defaultShortcut, for: target)
            shortcutStatusLabel = "\(targetLabel) shortcut was reset to the default because the saved combination could not be registered."
            return
        }

        shortcutStatusLabel = "\(targetLabel) shortcut could not be registered. Choose another combination from the menu bar."
    }

    private func openShortcutPanel() {
        cancelShortcutRecording()
        shortcutPanelController.update(shortcutSettings: shortcutSettings)
        shortcutPanelController.show(anchorRect: statusBarController?.statusButtonFrameInScreen)
    }

    @MainActor
    func shortcutPanelControllerForTesting() -> ShortcutPanelController {
        shortcutPanelController
    }

    @MainActor
    func shortcutStatusLabelForTesting() -> String? {
        shortcutStatusLabel
    }

    @MainActor
    func clipboardHotkeyMonitorForTesting() -> GlobalHotkeyMonitoring? {
        clipboardHotkeyMonitor
    }

    @MainActor
    func selectionHotkeyMonitorForTesting() -> GlobalHotkeyMonitoring? {
        selectionHotkeyMonitor
    }

    private func handleShortcutPanelAction(_ action: ShortcutPanelAction) -> Bool {
        switch action {
        case .startRecording:
            return true
        case let .saveRecordedShortcut(target, shortcut):
            let didApply = applyShortcutSettings(shortcut, for: target)
            if !didApply {
                shortcutPanelController.update(shortcutSettings: shortcutSettings)
            }
            return didApply
        case .resetToDefaults:
            let didReset = resetShortcutSettingsToDefaults()
            if !didReset {
                shortcutPanelController.update(shortcutSettings: shortcutSettings)
            }
            return didReset
        case .done:
            return true
        }
    }

    private func applyShortcutSettings(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) -> Bool {
        guard case let .success(updatedSettings) = shortcutSettings.replacing(shortcut, for: target) else {
            return false
        }

        guard reloadHotkeyMonitor(for: target, shortcut: shortcut) else {
            return false
        }

        restoreShortcutSettings(updatedSettings)
        return true
    }

    private func resetShortcutSettingsToDefaults() -> Bool {
        let previousSettings = shortcutSettings
        let defaultSettings = ShortcutSettings.default

        guard reloadHotkeyMonitor(for: .clipboard, shortcut: defaultSettings.clipboardShortcut) else {
            return false
        }

        guard reloadHotkeyMonitor(for: .selection, shortcut: defaultSettings.selectionShortcut) else {
            guard recoverHotkeyMonitors(afterFailedResetToDefaultsWith: previousSettings) else {
                return false
            }
            return false
        }

        restoreShortcutSettings(defaultSettings)
        return true
    }

    private func reloadHotkeyMonitor(
        for target: ShortcutTarget,
        shortcut: GlobalHotkeyShortcut
    ) -> Bool {
        switch target {
        case .clipboard:
            return clipboardHotkeyMonitor?.reload(shortcut: shortcut) ?? false
        case .selection:
            return selectionHotkeyMonitor?.reload(shortcut: shortcut) ?? false
        }
    }

    private func restoreShortcutSettings(_ settings: ShortcutSettings) {
        shortcutSettings = settings
        shortcutRecorder = ShortcutRecorder(
            existingSettings: settings,
            userDefaults: shortcutRecorderUserDefaults
        )
        settings.save(to: shortcutRecorderUserDefaults)
    }

    private func recoverHotkeyMonitors(
        afterFailedResetToDefaultsWith previousSettings: ShortcutSettings
    ) -> Bool {
        _ = reloadHotkeyMonitor(
            for: .clipboard,
            shortcut: previousSettings.clipboardShortcut
        )
        _ = reloadHotkeyMonitor(
            for: .selection,
            shortcut: previousSettings.selectionShortcut
        )

        if restoreLiveShortcutSettingsIfPossible(expectedSettings: previousSettings) {
            return true
        }

        rebuildHotkeyMonitor(
            for: .clipboard,
            shortcut: previousSettings.clipboardShortcut
        )
        rebuildHotkeyMonitor(
            for: .selection,
            shortcut: previousSettings.selectionShortcut
        )
        return restoreLiveShortcutSettingsIfPossible(expectedSettings: previousSettings)
    }

    private func restoreLiveShortcutSettingsIfPossible(
        expectedSettings: ShortcutSettings
    ) -> Bool {
        guard ensureHotkeyMonitorRunning(for: .clipboard),
              ensureHotkeyMonitorRunning(for: .selection),
              let effectiveSettings = liveShortcutSettingsSnapshot(),
              effectiveSettings == expectedSettings else {
            return false
        }
        restoreShortcutSettings(effectiveSettings)
        return true
    }

    private func ensureHotkeyMonitorRunning(for target: ShortcutTarget) -> Bool {
        guard let monitor = hotkeyMonitor(for: target) else {
            return false
        }
        if monitor.isRunning {
            return true
        }
        return monitor.start()
    }

    private func rebuildHotkeyMonitor(
        for target: ShortcutTarget,
        shortcut: GlobalHotkeyShortcut
    ) {
        hotkeyMonitor(for: target)?.stop()
        assignHotkeyMonitor(
            makeHotkeyMonitor(for: target, shortcut: shortcut),
            for: target
        )
    }

    private func liveShortcutSettingsSnapshot() -> ShortcutSettings? {
        guard let clipboardHotkeyMonitor,
              let selectionHotkeyMonitor,
              clipboardHotkeyMonitor.isRunning,
              selectionHotkeyMonitor.isRunning else {
            return nil
        }
        return ShortcutSettings(
            clipboardShortcut: clipboardHotkeyMonitor.configuredShortcut,
            selectionShortcut: selectionHotkeyMonitor.configuredShortcut
        )
    }

    private func hotkeyMonitor(for target: ShortcutTarget) -> GlobalHotkeyMonitoring? {
        switch target {
        case .clipboard:
            clipboardHotkeyMonitor
        case .selection:
            selectionHotkeyMonitor
        }
    }

    private func assignHotkeyMonitor(
        _ monitor: GlobalHotkeyMonitoring,
        for target: ShortcutTarget
    ) {
        switch target {
        case .clipboard:
            clipboardHotkeyMonitor = monitor
        case .selection:
            selectionHotkeyMonitor = monitor
        }
    }

    private func makeHotkeyMonitor(
        for target: ShortcutTarget,
        shortcut: GlobalHotkeyShortcut
    ) -> GlobalHotkeyMonitoring {
        switch target {
        case .clipboard:
            hotkeyMonitorFactory(1, shortcut) { [weak self] in
                self?.translateClipboard()
            }
        case .selection:
            hotkeyMonitorFactory(2, shortcut) { [weak self] in
                self?.handleSelectionTranslation()
            }
        }
    }

    private func persist(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) {
        guard case let .success(updatedSettings) = shortcutSettings.replacing(shortcut, for: target) else {
            return
        }

        shortcutSettings = updatedSettings
        updatedSettings.save(to: shortcutRecorderUserDefaults)
    }

    func beginShortcutRecording(for target: ShortcutTarget) {
        recordingTarget = target
        shortcutStatusLabel = recordingStatusLabel(for: target)
        clipboardHotkeyMonitor?.stop()
        selectionHotkeyMonitor?.stop()
        installShortcutRecordingMonitors()
        NSApp.activate(ignoringOtherApps: true)
    }

    func cancelShortcutRecording() {
        finishShortcutRecording(restartHotkeyMonitors: true)
    }

    private func finishShortcutRecording(restartHotkeyMonitors: Bool) {
        let wasRecording = recordingTarget != nil
        recordingTarget = nil
        shortcutStatusLabel = nil
        removeShortcutRecordingMonitors()
        if wasRecording, restartHotkeyMonitors {
            _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
            _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
        }
    }

    private func installShortcutRecordingMonitors() {
        removeShortcutRecordingMonitors()

        // 菜单点击后会立刻收起，这里同时监听本地与全局按键来接住下一次组合键输入。
        localShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleShortcutRecordingEvent(event)
            return nil
        }
        globalShortcutRecordingMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleShortcutRecordingEvent(event)
        }
    }

    private func removeShortcutRecordingMonitors() {
        if let localShortcutRecordingMonitor {
            NSEvent.removeMonitor(localShortcutRecordingMonitor)
            self.localShortcutRecordingMonitor = nil
        }
        if let globalShortcutRecordingMonitor {
            NSEvent.removeMonitor(globalShortcutRecordingMonitor)
            self.globalShortcutRecordingMonitor = nil
        }
    }

    private func handleShortcutRecordingEvent(_ event: NSEvent) {
        guard recordingTarget != nil else {
            return
        }

        if ShortcutRecorder.isCancelEvent(event) {
            cancelShortcutRecording()
            return
        }

        guard let shortcut = ShortcutRecorder.shortcut(from: event) else {
            return
        }

        applyRecordedShortcut(shortcut)
    }

    func applyRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) {
        guard let recordingTarget else {
            return
        }

        applyRecordedShortcut(shortcut, for: recordingTarget)
    }

    private func applyRecordedShortcut(
        _ shortcut: GlobalHotkeyShortcut,
        for target: ShortcutTarget
    ) {
        switch shortcutRecorder.validate(shortcut, for: target) {
        case .success:
            switch target {
            case .clipboard:
                guard clipboardHotkeyMonitor?.reload(shortcut: shortcut) ?? false else {
                    shortcutStatusLabel = "Shortcut could not be registered. Try another combination."
                    return
                }
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .clipboard) else {
                    shortcutStatusLabel = "Shortcut already in use. Try another combination."
                    _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
                    return
                }
                shortcutSettings = savedSettings
                _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
                finishShortcutRecording(restartHotkeyMonitors: false)
            case .selection:
                guard selectionHotkeyMonitor?.reload(shortcut: shortcut) ?? false else {
                    shortcutStatusLabel = "Shortcut could not be registered. Try another combination."
                    return
                }
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .selection) else {
                    shortcutStatusLabel = "Shortcut already in use. Try another combination."
                    _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
                    return
                }
                shortcutSettings = savedSettings
                _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
                finishShortcutRecording(restartHotkeyMonitors: false)
            }
        case .failure(.duplicateShortcut):
            shortcutStatusLabel = "Shortcut already in use. Try another combination."
        }
    }

    private func recordingStatusLabel(for target: ShortcutTarget) -> String {
        let title = switch target {
        case .clipboard:
            "Clipboard"
        case .selection:
            "Selection"
        }
        return "Recording \(title) Shortcut. Press the new key combination."
    }
}
