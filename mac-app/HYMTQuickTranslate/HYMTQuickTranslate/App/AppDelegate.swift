import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchCoordinator = AppLaunchCoordinator()
    private let overlayController = OverlayPanelController()
    private let workflow = TranslateClipboardWorkflow()
    private var hotkeyMonitor: GlobalHotkeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotkeyIfNeeded(immediatelyAfterLaunch: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
        hotkeyMonitor = nil
    }

    private func handleHotkey() {
        Task {
            overlayController.show(state: .loading)
            let state = await workflow.handleShortcut()
            present(state)
        }
    }

    private func confirmTranslation(_ text: String) {
        Task {
            overlayController.show(state: .loading)
            let state = await workflow.confirmTranslation(for: text)
            present(state)
        }
    }

    private func registerHotkeyIfNeeded(immediatelyAfterLaunch: Bool) {
        guard launchCoordinator.shouldRegisterHotkey(
            immediatelyAfterLaunch: immediatelyAfterLaunch
        ) else {
            DispatchQueue.main.async { [weak self] in
                self?.registerHotkeyIfNeeded(immediatelyAfterLaunch: false)
            }
            return
        }

        if hotkeyMonitor == nil {
            hotkeyMonitor = GlobalHotkeyMonitor { [weak self] in
                self?.handleHotkey()
            }
        }
        hotkeyMonitor?.start()
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
}
