import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    private let panelWidth: CGFloat = 460
    private let presentationOffset: CGFloat = 12
    private let mouseEventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    private let viewModel: OverlayViewModel
    private let panel: OverlayPanel
    private let dismissalPolicy: OverlayDismissalPolicy
    private let sizingPolicy: OverlaySizingPolicy
    private var lastShownAt: TimeInterval?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init(
        viewModel: OverlayViewModel = OverlayViewModel(),
        dismissalPolicy: OverlayDismissalPolicy = .default,
        sizingPolicy: OverlaySizingPolicy = .default
    ) {
        self.viewModel = viewModel
        self.dismissalPolicy = dismissalPolicy
        self.sizingPolicy = sizingPolicy
        self.panel = OverlayPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: panelWidth,
                height: sizingPolicy.minHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
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
        installClickMonitorsIfNeeded()
    }

    func show(
        state: OverlayViewState,
        onConfirm: ((String) -> Void)? = nil
    ) {
        lastShownAt = ProcessInfo.processInfo.systemUptime
        viewModel.show(state, onConfirm: onConfirm)
        resizePanel(for: state)
        panel.center()
        presentPanel()
    }

    func closePanel() {
        panel.alphaValue = 1
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

    private func resizePanel(for state: OverlayViewState) {
        let targetHeight: CGFloat

        switch state {
        case .loading:
            targetHeight = sizingPolicy.minHeight
        case let .result(text), let .error(text), let .confirmLongText(text):
            targetHeight = sizingPolicy.height(for: text)
        }

        var frame = panel.frame
        frame.origin.y += frame.height - targetHeight
        frame.size = NSSize(width: panelWidth, height: targetHeight)
        panel.setFrame(frame, display: true)
    }

    private func presentPanel() {
        NSApp.activate(ignoringOtherApps: true)

        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let targetFrame = panel.frame
        var startingFrame = targetFrame
        startingFrame.origin.y -= presentationOffset
        startingFrame.size.width *= 0.98
        startingFrame.origin.x += (targetFrame.width - startingFrame.width) / 2

        panel.alphaValue = 0
        panel.setFrame(startingFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func installClickMonitorsIfNeeded() {
        guard localClickMonitor == nil, globalClickMonitor == nil else {
            return
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEventMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handlePotentialClickAway()
            }
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEventMask) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePotentialClickAway()
            }
        }
    }

    private func handlePotentialClickAway() {
        guard panel.isVisible, let lastShownAt else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard dismissalPolicy.shouldCloseOnClickAway(shownAt: lastShownAt, now: now) else {
            return
        }

        guard panel.frame.contains(NSEvent.mouseLocation) == false else {
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
