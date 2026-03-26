import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    private static let anchorVerticalGap: CGFloat = 18
    private static let anchorMargin: CGFloat = 16

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
        placement: OverlayPlacement = .centered,
        onConfirm: ((String) -> Void)? = nil
    ) {
        lastShownAt = ProcessInfo.processInfo.systemUptime
        viewModel.show(state, onConfirm: onConfirm)
        apply(placement)
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

    private func apply(_ placement: OverlayPlacement) {
        switch placement {
        case .centered:
            panel.center()
        case let .anchored(anchor):
            guard let screen = screen(containing: anchor) else {
                panel.center()
                return
            }

            let panelSize = panel.frame.size
            let visibleFrame = screen.visibleFrame
            let minX = visibleFrame.minX + Self.anchorMargin
            let maxX = visibleFrame.maxX - panelSize.width - Self.anchorMargin
            let minY = visibleFrame.minY + Self.anchorMargin
            let maxY = visibleFrame.maxY - panelSize.height - Self.anchorMargin

            var originX = anchor.x - (panelSize.width / 2)
            originX = min(max(originX, minX), maxX)

            let preferredBelowY = anchor.y - panelSize.height - Self.anchorVerticalGap
            let fallbackAboveY = anchor.y + Self.anchorVerticalGap
            let originY = if preferredBelowY >= minY {
                preferredBelowY
            } else {
                min(fallbackAboveY, maxY)
            }

            panel.setFrameOrigin(
                NSPoint(
                    x: originX,
                    y: min(max(originY, minY), maxY)
                )
            )
        }
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
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
