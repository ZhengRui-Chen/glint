import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
enum ScreenRegionSelectionResult: @unchecked Sendable {
    case cancelled
    case captureFailed(String)
    case selected(CGImage, CGRect)
}

@MainActor
final class ScreenRegionSelectionController: NSObject, NSWindowDelegate {
    private let model: ScreenRegionSelectionModel
    private let panel: ScreenRegionSelectionPanel
    private let trackingView = ScreenRegionTrackingView()
    private var completion: (@MainActor @Sendable (ScreenRegionSelectionResult) -> Void)?

    init(model: ScreenRegionSelectionModel = ScreenRegionSelectionModel()) {
        self.model = model
        self.panel = ScreenRegionSelectionPanel(
            contentRect: Self.selectionFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false

        let rootView = ScreenRegionSelectionRootView(
            contentView: ScreenRegionSelectionView(model: model),
            trackingView: trackingView
        )
        rootView.frame = panel.contentView?.bounds ?? .zero
        rootView.autoresizingMask = [.width, .height]
        panel.contentView = rootView

        trackingView.onBegin = { [weak self] point in
            self?.model.beginSelection(at: point)
        }
        trackingView.onChange = { [weak self] point in
            self?.model.updateSelection(at: point)
        }
        trackingView.onEnd = { [weak self] point in
            self?.finishSelection(at: point)
        }
        trackingView.onCancel = { [weak self] in
            self?.cancelSelection()
        }
    }

    func present(
        completion: @escaping @MainActor @Sendable (ScreenRegionSelectionResult) -> Void
    ) {
        self.completion = completion
        model.cancelSelection()
        panel.setFrame(Self.selectionFrame(), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(trackingView)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        cancelSelection()
    }

    private func finishSelection(at point: CGPoint) {
        guard let localRect = model.finishSelection(at: point) else {
            dismiss(with: .cancelled)
            return
        }

        let selectedRect = localRect.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY).integral
        let captureRect = ScreenRegionSelectionLayout.captureRect(
            for: localRect,
            panelFrame: panel.frame,
            desktopFrame: Self.selectionFrame()
        ).integral

        guard let image = captureImage(for: captureRect) else {
            dismiss(with: .captureFailed(L10n.unableToCaptureSelectedArea))
            return
        }

        dismiss(with: .selected(image, selectedRect))
    }

    private func cancelSelection() {
        model.cancelSelection()
        dismiss(with: .cancelled)
    }

    private func dismiss(with result: ScreenRegionSelectionResult) {
        let completion = self.completion
        self.completion = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                completion?(result)
            }
        }
    }

    private func captureImage(for rect: CGRect) -> CGImage? {
        CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    private static func selectionFrame() -> CGRect {
        NSScreen.screens
            .map(\.frame)
            .reduce(.null) { partialResult, frame in
                partialResult.union(frame)
            }
    }
}

private final class ScreenRegionSelectionPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

private final class ScreenRegionSelectionRootView<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private let trackingView: ScreenRegionTrackingView

    init(contentView: Content, trackingView: ScreenRegionTrackingView) {
        self.hostingView = NSHostingView(rootView: contentView)
        self.trackingView = trackingView
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        addSubview(trackingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            trackingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScreenRegionTrackingView: NSView {
    var onBegin: (CGPoint) -> Void = { _ in }
    var onChange: (CGPoint) -> Void = { _ in }
    var onEnd: (CGPoint) -> Void = { _ in }
    var onCancel: () -> Void = {}

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onBegin(event.locationInWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        onChange(event.locationInWindow)
    }

    override func mouseUp(with event: NSEvent) {
        onEnd(event.locationInWindow)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }
}
