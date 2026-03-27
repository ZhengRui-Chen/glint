import AppKit

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
    private let ocrWorkflow = TranslateOCRWorkflow()
    private let selectionWorkflow = TranslateTextWorkflow(
        inputSource: SelectionInputSource(),
        noTextMessage: L10n.noSelectedTextFound,
        permissionRequiredMessage: L10n.accessibilityPermissionNotGranted,
        automationPermissionRequiredMessage: L10n.browserAutomationPermissionRetry,
        unsupportedHostAppMessage: L10n.unsupportedHostApp,
        rejectedTextMessage: L10n.textExceedsMaximumLength
    )
    private let overlayPlacementResolver = OverlayPlacementResolver()
    private let screenRegionSelectionController = ScreenRegionSelectionController()
    private let launchCoordinator: any AppLaunchCoordinating
    private let shortcutRecorderUserDefaults: UserDefaults
    private let hotkeyMonitorFactory: HotkeyMonitorFactory
    nonisolated(unsafe) private let backendStatusMonitor: BackendStatusMonitor
    private let apiSettingsStore: APISettingsStore
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
    private lazy var apiSettingsPanelController = APISettingsPanelController(
        store: apiSettingsStore,
        onSave: { [weak self] in
        self?.refreshBackendStatus()
        }
    )
    private var clipboardHotkeyMonitor: GlobalHotkeyMonitoring?
    private var selectionHotkeyMonitor: GlobalHotkeyMonitoring?
    private var ocrHotkeyMonitor: GlobalHotkeyMonitoring?
    private var statusBarController: StatusBarController?
    private var recordingTarget: ShortcutTarget?
    private var shortcutStatusLabel: String?
    private var backendStatus = BackendStatusSnapshot.checking()
    private var backendRefreshGeneration = 0
    private var localShortcutRecordingMonitor: Any?
    private var globalShortcutRecordingMonitor: Any?

    override init() {
        shortcutSettings = .load()
        launchCoordinator = AppLaunchCoordinator()
        shortcutRecorderUserDefaults = .standard
        hotkeyMonitorFactory = Self.defaultHotkeyMonitorFactory
        backendStatusMonitor = BackendStatusMonitor()
        apiSettingsStore = APISettingsStore()
        super.init()
    }

    init(
        shortcutSettings: ShortcutSettings = .load(),
        launchCoordinator: any AppLaunchCoordinating = AppLaunchCoordinator(),
        shortcutRecorderUserDefaults: UserDefaults = .standard,
        hotkeyMonitorFactory: @escaping HotkeyMonitorFactory = AppDelegate.defaultHotkeyMonitorFactory,
        backendStatusMonitor: BackendStatusMonitor = BackendStatusMonitor(),
        apiSettingsStore: APISettingsStore = APISettingsStore()
    ) {
        self.shortcutSettings = shortcutSettings
        self.launchCoordinator = launchCoordinator
        self.shortcutRecorderUserDefaults = shortcutRecorderUserDefaults
        self.hotkeyMonitorFactory = hotkeyMonitorFactory
        self.backendStatusMonitor = backendStatusMonitor
        self.apiSettingsStore = apiSettingsStore
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController { [weak self] in
            self?.makeMenuBarViewModel() ?? MenuBarViewModel(
                permissionStatus: .required,
                backendStatus: .checking()
            )
        }
        refreshBackendStatus()
        registerHotkeysIfNeeded(immediatelyAfterLaunch: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardHotkeyMonitor?.stop()
        clipboardHotkeyMonitor = nil
        selectionHotkeyMonitor?.stop()
        selectionHotkeyMonitor = nil
        ocrHotkeyMonitor?.stop()
        ocrHotkeyMonitor = nil
        removeShortcutRecordingMonitors()
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
                state: .error(L10n.accessibilityPermissionRequiredForSelectionTranslation),
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

    private func handleOCRTranslation() {
        screenRegionSelectionController.present { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .cancelled:
                return
            case let .captureFailed(message):
                self.present(.error(message), placement: .centered)
            case let .selected(image, rect):
                let placement = overlayPlacementResolver.resolve(
                    cursorAnchor: CGPoint(x: rect.midX, y: rect.minY)
                )
                Task {
                    switch await ocrWorkflow.prepare(image: image) {
                    case let .translate(recognition):
                        overlayController.show(state: .loading, placement: placement)
                        let state = await ocrWorkflow.confirmTranslation(for: recognition)
                        present(state, placement: placement)
                    case let .confirm(recognition):
                        overlayController.show(
                            state: .confirmLongText(recognition.text),
                            placement: placement
                        ) { [weak self] _ in
                            guard let self else {
                                return
                            }
                            Task {
                                self.overlayController.show(state: .loading, placement: placement)
                                let state = await self.ocrWorkflow.confirmTranslation(for: recognition)
                                self.present(state, placement: placement)
                            }
                        }
                    case let .final(state):
                        present(state, placement: placement)
                    }
                }
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
            onTranslateOCR: { [weak self] in
                self?.handleOCRTranslation()
            },
            onOpenAPISettings: { [weak self] in
                self?.openAPISettings()
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

    private func openAPISettings() {
        cancelShortcutRecording()
        apiSettingsPanelController.show(
            anchorRect: statusBarController?.statusButtonFrameInScreen
        )
    }

    private func refreshBackendStatus() {
        let refreshGeneration = nextBackendRefreshGeneration()
        updateBackendStatus(.checking())
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let snapshot = await backendStatusMonitor.refresh()
            guard shouldApplyBackendRefreshResult(for: refreshGeneration) else {
                return
            }
            updateBackendStatus(snapshot)
        }
    }

    private func nextBackendRefreshGeneration() -> Int {
        backendRefreshGeneration += 1
        return backendRefreshGeneration
    }

    private func shouldApplyBackendRefreshResult(for refreshGeneration: Int) -> Bool {
        refreshGeneration == backendRefreshGeneration
    }

    private func updateBackendStatus(_ snapshot: BackendStatusSnapshot) {
        backendStatus = snapshot
        statusBarController?.refreshMenu()
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

        if ocrHotkeyMonitor == nil {
            ocrHotkeyMonitor = hotkeyMonitorFactory(
                3,
                shortcutSettings.ocrShortcut
            ) { [weak self] in
                self?.handleOCRTranslation()
            }
        }
        startHotkeyMonitor(
            ocrHotkeyMonitor,
            target: .ocr,
            configuredShortcut: shortcutSettings.ocrShortcut,
            defaultShortcut: .ocrDefault
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
            L10n.shortcutTargetClipboard
        case .selection:
            L10n.shortcutTargetSelection
        case .ocr:
            L10n.shortcutTargetOCR
        }

        if configuredShortcut != defaultShortcut,
           monitor.reload(shortcut: defaultShortcut) {
            persist(defaultShortcut, for: target)
            shortcutStatusLabel = L10n.shortcutResetToDefault(target: targetLabel)
            return
        }

        shortcutStatusLabel = L10n.shortcutCouldNotBeRegisteredFromMenu(target: targetLabel)
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
    func apiSettingsPanelControllerForTesting() -> APISettingsPanelController {
        apiSettingsPanelController
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

    @MainActor
    func ocrHotkeyMonitorForTesting() -> GlobalHotkeyMonitoring? {
        ocrHotkeyMonitor
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

        guard reloadHotkeyMonitor(for: .ocr, shortcut: defaultSettings.ocrShortcut) else {
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
        case .ocr:
            return ocrHotkeyMonitor?.reload(shortcut: shortcut) ?? false
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
        _ = reloadHotkeyMonitor(
            for: .ocr,
            shortcut: previousSettings.ocrShortcut
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
        rebuildHotkeyMonitor(
            for: .ocr,
            shortcut: previousSettings.ocrShortcut
        )
        return restoreLiveShortcutSettingsIfPossible(expectedSettings: previousSettings)
    }

    private func restoreLiveShortcutSettingsIfPossible(
        expectedSettings: ShortcutSettings
    ) -> Bool {
        guard ensureHotkeyMonitorRunning(for: .clipboard),
              ensureHotkeyMonitorRunning(for: .selection),
              ensureHotkeyMonitorRunning(for: .ocr),
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
              let ocrHotkeyMonitor,
              clipboardHotkeyMonitor.isRunning,
              selectionHotkeyMonitor.isRunning,
              ocrHotkeyMonitor.isRunning else {
            return nil
        }
        return ShortcutSettings(
            clipboardShortcut: clipboardHotkeyMonitor.configuredShortcut,
            selectionShortcut: selectionHotkeyMonitor.configuredShortcut,
            ocrShortcut: ocrHotkeyMonitor.configuredShortcut
        )
    }

    private func hotkeyMonitor(for target: ShortcutTarget) -> GlobalHotkeyMonitoring? {
        switch target {
        case .clipboard:
            clipboardHotkeyMonitor
        case .selection:
            selectionHotkeyMonitor
        case .ocr:
            ocrHotkeyMonitor
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
        case .ocr:
            ocrHotkeyMonitor = monitor
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
        case .ocr:
            hotkeyMonitorFactory(3, shortcut) { [weak self] in
                self?.handleOCRTranslation()
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
        ocrHotkeyMonitor?.stop()
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
            _ = ocrHotkeyMonitor?.reload(shortcut: shortcutSettings.ocrShortcut)
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
                    shortcutStatusLabel = L10n.shortcutCouldNotBeRegisteredTryAnother
                    return
                }
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .clipboard) else {
                    shortcutStatusLabel = L10n.shortcutAlreadyInUseTryAnother
                    _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
                    return
                }
                shortcutSettings = savedSettings
                _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
                finishShortcutRecording(restartHotkeyMonitors: false)
            case .selection:
                guard selectionHotkeyMonitor?.reload(shortcut: shortcut) ?? false else {
                    shortcutStatusLabel = L10n.shortcutCouldNotBeRegisteredTryAnother
                    return
                }
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .selection) else {
                    shortcutStatusLabel = L10n.shortcutAlreadyInUseTryAnother
                    _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
                    return
                }
                shortcutSettings = savedSettings
                _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
                finishShortcutRecording(restartHotkeyMonitors: false)
            case .ocr:
                guard ocrHotkeyMonitor?.reload(shortcut: shortcut) ?? false else {
                    shortcutStatusLabel = L10n.shortcutCouldNotBeRegisteredTryAnother
                    return
                }
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .ocr) else {
                    shortcutStatusLabel = L10n.shortcutAlreadyInUseTryAnother
                    _ = ocrHotkeyMonitor?.reload(shortcut: shortcutSettings.ocrShortcut)
                    return
                }
                shortcutSettings = savedSettings
                _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
                _ = selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
                finishShortcutRecording(restartHotkeyMonitors: false)
            }
        case .failure(.duplicateShortcut):
            shortcutStatusLabel = L10n.shortcutAlreadyInUseTryAnother
        }
    }

    private func recordingStatusLabel(for target: ShortcutTarget) -> String {
        let title = switch target {
        case .clipboard:
            L10n.shortcutTargetClipboard
        case .selection:
            L10n.shortcutTargetSelection
        case .ocr:
            L10n.shortcutTargetOCR
        }
        return L10n.recordingShortcut(target: title)
    }
}
