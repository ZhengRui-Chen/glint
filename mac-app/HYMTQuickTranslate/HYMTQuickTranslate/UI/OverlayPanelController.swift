import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    private let viewModel: OverlayViewModel
    private let panel: OverlayPanel
    private let dismissalPolicy: OverlayDismissalPolicy
    private var lastShownAt: TimeInterval?

    init(
        viewModel: OverlayViewModel = OverlayViewModel(),
        dismissalPolicy: OverlayDismissalPolicy = .default
    ) {
        self.viewModel = viewModel
        self.dismissalPolicy = dismissalPolicy
        self.panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onCancel = { [weak self] in
            self?.closePanel()
        }
        panel.contentView = NSHostingView(rootView: OverlayContentView(viewModel: viewModel))

        viewModel.bindCloseAction { [weak self] in
            self?.closePanel()
        }
    }

    func show(
        state: OverlayViewState,
        onConfirm: ((String) -> Void)? = nil
    ) {
        lastShownAt = ProcessInfo.processInfo.systemUptime
        viewModel.show(state, onConfirm: onConfirm)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func closePanel() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastShownAt,
           dismissalPolicy.shouldCloseOnFocusLoss(shownAt: lastShownAt, now: now) == false {
            return
        }
        closePanel()
    }
}

private final class OverlayPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
