import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityPermission = AccessibilityPermission()
    private let overlayController = OverlayPanelController()
    private let workflow = TranslateClipboardWorkflow()
    private var shortcutSettings = ShortcutSettings.load()
    private lazy var shortcutRecorder = ShortcutRecorder(existingSettings: shortcutSettings)
    private var clipboardHotkeyMonitor: GlobalHotkeyMonitor?
    private var selectionHotkeyMonitor: GlobalHotkeyMonitor?
    private var statusBarController: StatusBarController?
    private var recordingTarget: ShortcutTarget?
    private var shortcutStatusLabel: String?
    private var localShortcutRecordingMonitor: Any?
    private var globalShortcutRecordingMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController { [weak self] in
            self?.makeMenuBarViewModel() ?? MenuBarViewModel(permissionStatus: .required)
        }
        configureHotkeyMonitors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardHotkeyMonitor?.stop()
        selectionHotkeyMonitor?.stop()
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
        clipboardHotkeyMonitor = GlobalHotkeyMonitor(
            identifier: 1,
            shortcut: shortcutSettings.clipboardShortcut
        ) { [weak self] in
            self?.translateClipboard()
        }
        selectionHotkeyMonitor = GlobalHotkeyMonitor(
            identifier: 2,
            shortcut: shortcutSettings.selectionShortcut
        ) { [weak self] in
            self?.handleSelectionTranslation()
        }
        clipboardHotkeyMonitor?.start()
        selectionHotkeyMonitor?.start()
    }

    private func reloadHotkeyMonitors() {
        clipboardHotkeyMonitor?.reload(shortcut: shortcutSettings.clipboardShortcut)
        selectionHotkeyMonitor?.reload(shortcut: shortcutSettings.selectionShortcut)
    }

    private func beginShortcutRecording(for target: ShortcutTarget) {
        recordingTarget = target
        shortcutStatusLabel = recordingStatusLabel(for: target)
        installShortcutRecordingMonitors()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func cancelShortcutRecording() {
        recordingTarget = nil
        shortcutStatusLabel = nil
        removeShortcutRecordingMonitors()
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
        guard let recordingTarget else {
            return
        }

        if ShortcutRecorder.isCancelEvent(event) {
            cancelShortcutRecording()
            return
        }

        guard let shortcut = ShortcutRecorder.shortcut(from: event) else {
            return
        }

        switch shortcutRecorder.save(shortcut, for: recordingTarget) {
        case let .success(updatedSettings):
            shortcutSettings = updatedSettings
            cancelShortcutRecording()
            reloadHotkeyMonitors()
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
