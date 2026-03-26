import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityPermission = AccessibilityPermission()
    private let overlayController = OverlayPanelController()
    private let workflow = TranslateClipboardWorkflow()
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController { [weak self] in
            self?.makeMenuBarViewModel() ?? MenuBarViewModel(permissionStatus: .required)
        }
        hotkeyMonitor = GlobalHotkeyMonitor { [weak self] in
            self?.translateClipboard()
        }
        hotkeyMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
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
            onTranslateSelection: { [weak self] in
                self?.handleSelectionTranslation()
            },
            onTranslateClipboard: { [weak self] in
                self?.translateClipboard()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }
}
