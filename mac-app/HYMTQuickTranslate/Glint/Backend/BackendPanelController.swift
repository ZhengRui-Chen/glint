import AppKit
import QuartzCore
import SwiftUI

enum BackendPanelAction: Equatable {
    case save(settings: BackendSettings)
    case checkBackend
    case close
}

@MainActor
final class BackendPanelController: NSObject, NSWindowDelegate {
    private static let panelWidth: CGFloat = 440
    private static let panelHeight: CGFloat = 404
    private static let presentationOffset: CGFloat = 12

    let onAction: ((BackendPanelAction) -> Bool)?

    private let viewModel: BackendPanelViewModel
    private let panel: BackendPanelWindow
    private let hostingView: NSHostingView<BackendPanelView>
    private var isClosing = false

    init(
        savedSettings: BackendSettings = .default,
        statusSnapshot: BackendStatusSnapshot = .notChecked(),
        onAction: ((BackendPanelAction) -> Bool)? = nil
    ) {
        self.viewModel = BackendPanelViewModel(
            savedSettings: savedSettings,
            statusSnapshot: statusSnapshot
        )
        self.onAction = onAction
        self.panel = BackendPanelWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.panelWidth,
                height: Self.panelHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.hostingView = NSHostingView(
            rootView: BackendPanelView(
                viewModel: viewModel,
                onCheckBackend: {},
                onResetToDefaults: {},
                onDone: {}
            )
        )
        super.init()

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onCancel = { [weak self] in
            self?.handleCancelOperation()
        }

        hostingView.rootView = makeRootView()
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func prepareForPresentation(
        savedSettings: BackendSettings,
        statusSnapshot: BackendStatusSnapshot
    ) {
        viewModel.prepareForPresentation(
            savedSettings: savedSettings,
            statusSnapshot: statusSnapshot
        )
    }

    func updateStatusSnapshot(_ statusSnapshot: BackendStatusSnapshot) {
        viewModel.updateStatusSnapshot(statusSnapshot)
    }

    func requestCheckBackend() {
        _ = emit(.checkBackend)
    }

    func requestResetToDefaults() {
        viewModel.resetDraftToDefaults()
    }

    func requestDone() {
        if viewModel.hasChanges {
            guard emit(.save(settings: viewModel.draftSettings)) else {
                return
            }
            viewModel.applySavedSettings(viewModel.draftSettings)
        }
        _ = emit(.close)
        closePanel()
    }

    func show(anchorRect: CGRect? = nil) {
        if panel.isVisible {
            orderPanelFront()
            return
        }

        isClosing = false
        let targetFrame = resolvedTargetFrame(anchorRect: anchorRect)
        let transition = BackendPanelTransition.present(offset: Self.presentationOffset)
        let startingFrame = transition.frame(fromVisibleFrame: targetFrame)

        panel.alphaValue = transition.initialAlpha
        panel.setFrame(startingFrame, display: false)
        orderPanelFront()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = transition.duration
            context.timingFunction = transition.timingFunction
            panel.animator().alphaValue = transition.finalAlpha
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    func closePanel() {
        guard panel.isVisible, isClosing == false else {
            return
        }

        isClosing = true
        let visibleFrame = panel.frame
        let transition = BackendPanelTransition.dismiss(offset: Self.presentationOffset)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = transition.duration
            context.timingFunction = transition.timingFunction
            panel.animator().alphaValue = transition.finalAlpha
            panel.animator().setFrame(transition.frame(fromVisibleFrame: visibleFrame), display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.panel.setFrame(visibleFrame, display: false)
                self.isClosing = false
            }
        }
    }

    var isPanelVisibleForTesting: Bool {
        panel.isVisible
    }

    var showsManagedControlActionsForTesting: Bool {
        viewModel.showsManagedControlActions
    }

    func applyDraftSettingsForTesting(_ settings: BackendSettings) {
        viewModel.updateBaseURL(settings.baseURL.absoluteString)
        viewModel.updateModel(settings.model)
        viewModel.updateAPIKey(settings.apiKey)
    }

    func handleCancelForTesting() {
        handleCancelOperation()
    }

    private func makeRootView() -> BackendPanelView {
        BackendPanelView(
            viewModel: viewModel,
            onCheckBackend: { [weak self] in
                self?.requestCheckBackend()
            },
            onResetToDefaults: { [weak self] in
                self?.requestResetToDefaults()
            },
            onDone: { [weak self] in
                self?.requestDone()
            }
        )
    }

    @discardableResult
    private func emit(_ action: BackendPanelAction) -> Bool {
        onAction?(action) ?? true
    }

    private func orderPanelFront() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func resolvedTargetFrame(anchorRect: CGRect?) -> CGRect {
        let panelSize = CGSize(width: Self.panelWidth, height: Self.panelHeight)

        if let anchorRect {
            let screen = NSScreen.screens.first { $0.frame.intersects(anchorRect) } ?? NSScreen.main
            if let screen {
                return BackendPanelPlacement.frame(
                    panelSize: panelSize,
                    anchorRect: anchorRect,
                    screenFrame: screen.frame,
                    visibleFrame: screen.visibleFrame
                )
            }
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? CGRect(
            x: 0,
            y: 0,
            width: panelSize.width,
            height: panelSize.height
        )
        return CGRect(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private func handleCancelOperation() {
        closePanel()
    }
}

private struct BackendPanelPlacement {
    static func frame(
        panelSize: CGSize,
        anchorRect: CGRect,
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        let horizontalMargin: CGFloat = 24
        let verticalGap: CGFloat = 10

        let maxX = visibleFrame.maxX - panelSize.width - horizontalMargin
        let minX = visibleFrame.minX + horizontalMargin
        let preferredX = anchorRect.maxX - panelSize.width
        let x = min(max(preferredX, minX), maxX)

        let aboveAnchorY = anchorRect.minY - panelSize.height - verticalGap
        let belowAnchorY = anchorRect.maxY + verticalGap
        let minY = visibleFrame.minY + horizontalMargin
        let maxY = visibleFrame.maxY - panelSize.height - horizontalMargin
        let preferredY = aboveAnchorY >= minY ? aboveAnchorY : belowAnchorY
        let y = min(max(preferredY, minY), maxY)

        return CGRect(
            x: x,
            y: y,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

private struct BackendPanelTransition {
    let duration: TimeInterval
    let timingFunction: CAMediaTimingFunction
    let initialAlpha: CGFloat
    let finalAlpha: CGFloat
    let yOffset: CGFloat

    static func present(offset: CGFloat) -> BackendPanelTransition {
        BackendPanelTransition(
            duration: 0.18,
            timingFunction: CAMediaTimingFunction(name: .easeOut),
            initialAlpha: 0,
            finalAlpha: 1,
            yOffset: offset
        )
    }

    static func dismiss(offset: CGFloat) -> BackendPanelTransition {
        BackendPanelTransition(
            duration: 0.16,
            timingFunction: CAMediaTimingFunction(name: .easeIn),
            initialAlpha: 1,
            finalAlpha: 0,
            yOffset: offset
        )
    }

    func frame(fromVisibleFrame frame: CGRect) -> CGRect {
        frame.offsetBy(dx: 0, dy: yOffset)
    }
}

private final class BackendPanelWindow: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
