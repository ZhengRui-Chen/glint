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
    private let shortcutRecorderUserDefaults: UserDefaults
    private let hotkeyMonitorFactory: HotkeyMonitorFactory
    private var shortcutSettings: ShortcutSettings
    private lazy var shortcutRecorder = ShortcutRecorder(
        existingSettings: shortcutSettings,
        userDefaults: shortcutRecorderUserDefaults
    )
    private var clipboardHotkeyMonitor: GlobalHotkeyMonitoring?
    private var statusBarController: StatusBarController?
    private var recordingTarget: ShortcutTarget?
    private var shortcutStatusLabel: String?
    private var localShortcutRecordingMonitor: Any?
    private var globalShortcutRecordingMonitor: Any?

    override init() {
        shortcutSettings = .load()
        shortcutRecorderUserDefaults = .standard
        hotkeyMonitorFactory = Self.defaultHotkeyMonitorFactory
        super.init()
    }

    init(
        shortcutSettings: ShortcutSettings = .load(),
        shortcutRecorderUserDefaults: UserDefaults = .standard,
        hotkeyMonitorFactory: @escaping HotkeyMonitorFactory = AppDelegate.defaultHotkeyMonitorFactory
    ) {
        self.shortcutSettings = shortcutSettings
        self.shortcutRecorderUserDefaults = shortcutRecorderUserDefaults
        self.hotkeyMonitorFactory = hotkeyMonitorFactory
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController { [weak self] in
            self?.makeMenuBarViewModel() ?? MenuBarViewModel(permissionStatus: .required)
        }
        configureHotkeyMonitors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardHotkeyMonitor?.stop()
        removeShortcutRecordingMonitors()
    }

    private func translateClipboard() {
        Task {
            overlayController.show(state: .loading)
            let state = await workflow.handleShortcut()
            present(state)
        }
    }

    private func handleSelectionTranslation() {
        let message = if accessibilityPermission.isGranted {
            "Selection translation will be added in a later task."
        } else {
            "Accessibility permission is required for selection translation."
        }
        overlayController.show(state: .error(message))
    }

    private func confirmTranslation(_ text: String) {
        Task {
            overlayController.show(state: .loading)
            let state = await workflow.confirmTranslation(for: text)
            present(state)
        }
    }

    // 所有入口都收敛到同一个面板状态机，避免多窗口分叉。
    private func present(_ state: OverlayViewState) {
        switch state {
        case let .confirmLongText(text):
            overlayController.show(state: state) { [weak self] _ in
                self?.confirmTranslation(text)
            }
        default:
            overlayController.show(state: state)
        }
    }

    private func makeMenuBarViewModel() -> MenuBarViewModel {
        MenuBarViewModel(
            permissionStatus: accessibilityPermission.isGranted ? .granted : .required,
            shortcutSettings: shortcutSettings,
            recordingTarget: recordingTarget,
            shortcutStatusLabel: shortcutStatusLabel,
            onTranslateSelection: { [weak self] in
                self?.handleSelectionTranslation()
            },
            onTranslateClipboard: { [weak self] in
                self?.translateClipboard()
            },
            onStartRecording: { [weak self] target in
                self?.beginShortcutRecording(for: target)
            },
            onCancelShortcutRecording: { [weak self] in
                self?.cancelShortcutRecording()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func configureHotkeyMonitors() {
        clipboardHotkeyMonitor = hotkeyMonitorFactory(
            1,
            shortcutSettings.clipboardShortcut
        ) { [weak self] in
            self?.translateClipboard()
        }
        _ = clipboardHotkeyMonitor?.start()
    }

    func beginShortcutRecording(for target: ShortcutTarget) {
        recordingTarget = target
        shortcutStatusLabel = recordingStatusLabel(for: target)
        clipboardHotkeyMonitor?.stop()
        installShortcutRecordingMonitors()
        NSApp.activate(ignoringOtherApps: true)
    }

    func cancelShortcutRecording() {
        finishShortcutRecording(restartClipboardMonitor: true)
    }

    private func finishShortcutRecording(restartClipboardMonitor: Bool) {
        let wasRecording = recordingTarget != nil
        recordingTarget = nil
        shortcutStatusLabel = nil
        removeShortcutRecordingMonitors()
        if wasRecording, restartClipboardMonitor {
            _ = clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
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

        switch shortcutRecorder.validate(shortcut, for: recordingTarget) {
        case .success:
            switch recordingTarget {
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
                finishShortcutRecording(restartClipboardMonitor: false)
            case .selection:
                guard case let .success(savedSettings) = shortcutRecorder.save(shortcut, for: .selection) else {
                    shortcutStatusLabel = "Shortcut already in use. Try another combination."
                    return
                }
                shortcutSettings = savedSettings
                finishShortcutRecording(restartClipboardMonitor: true)
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
