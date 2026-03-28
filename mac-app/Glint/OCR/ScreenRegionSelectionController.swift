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
final class ScreenRegionSelectionController: NSObject {
    private let model: ScreenRegionSelectionModel
    private let screenFramesProvider: @MainActor () -> [CGRect]
    private var panels: [ScreenRegionSelectionPanelContext] = []
    private var completion: (@MainActor @Sendable (ScreenRegionSelectionResult) -> Void)?
    private var activeScreenFrame: CGRect?
    private var keyMonitor: Any?
    private var dragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    init(
        model: ScreenRegionSelectionModel = ScreenRegionSelectionModel(),
        screenFramesProvider: @escaping @MainActor () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        }
    ) {
        self.model = model
        self.screenFramesProvider = screenFramesProvider
        super.init()
    }

    func present(
        completion: @escaping @MainActor @Sendable (ScreenRegionSelectionResult) -> Void
    ) {
        self.completion = completion
        activeScreenFrame = nil
        model.cancelSelection()
        rebuildPanels()
        installInteractionMonitors()

        guard panels.isEmpty == false else {
            dismiss(with: .captureFailed(L10n.unableToCaptureSelectedArea))
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        for (index, context) in panels.enumerated() {
            context.panel.setFrame(context.screenFrame, display: false)
            context.panel.alphaValue = 0
            if index == 0 {
                context.panel.makeKeyAndOrderFront(nil)
                context.panel.makeFirstResponder(context.trackingView)
            } else {
                context.panel.orderFrontRegardless()
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            for panelContext in panels {
                panelContext.panel.animator().alphaValue = 1
            }
        }
    }

    private func rebuildPanels() {
        panels.forEach { $0.panel.orderOut(nil) }
        panels.removeAll()

        let screenFrames = ScreenRegionSelectionLayout.panelFrames(
            for: screenFramesProvider()
        )
        panels = screenFrames.map(makePanelContext(screenFrame:))
    }

    private func finishSelection(at point: CGPoint) {
        activeScreenFrame = nil

        guard let selectedRect = model.finishSelection(at: point)?.integral else {
            dismiss(with: .cancelled)
            return
        }

        let captureRect = ScreenRegionSelectionLayout.captureRect(
            forGlobalRect: selectedRect,
            desktopFrame: desktopFrame()
        ).integral

        guard let image = captureImage(for: captureRect) else {
            dismiss(with: .captureFailed(L10n.unableToCaptureSelectedArea))
            return
        }

        dismiss(with: .selected(image, selectedRect))
    }

    private func cancelSelection() {
        activeScreenFrame = nil
        model.cancelSelection()
        dismiss(with: .cancelled)
    }

    private func dismiss(with result: ScreenRegionSelectionResult) {
        let completion = self.completion
        self.completion = nil
        removeInteractionMonitors()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            for panelContext in panels {
                panelContext.panel.animator().alphaValue = 0
            }
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                self.panels.forEach {
                    $0.panel.orderOut(nil)
                    $0.panel.alphaValue = 1
                }
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

    private func desktopFrame() -> CGRect {
        screenFramesProvider()
            .reduce(.null) { partialResult, frame in
                partialResult.union(frame)
            }
    }

    private func makePanelContext(screenFrame: CGRect) -> ScreenRegionSelectionPanelContext {
        let panel = ScreenRegionSelectionPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let trackingView = ScreenRegionTrackingView()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false

        let rootView = ScreenRegionSelectionRootView(
            contentView: ScreenRegionSelectionView(
                model: model,
                screenFrame: screenFrame
            ),
            trackingView: trackingView
        )
        rootView.frame = CGRect(origin: .zero, size: screenFrame.size)
        rootView.autoresizingMask = [.width, .height]
        panel.contentView = rootView

        trackingView.onBegin = { [weak self] point in
            self?.beginSelection(
                at: CGPoint(
                    x: point.x + screenFrame.minX,
                    y: point.y + screenFrame.minY
                ),
                screenFrame: screenFrame
            )
        }
        trackingView.onCancel = { [weak self] in
            self?.cancelSelection()
        }

        return ScreenRegionSelectionPanelContext(
            panel: panel,
            trackingView: trackingView,
            screenFrame: screenFrame
        )
    }

    private func beginSelection(at point: CGPoint, screenFrame: CGRect) {
        activeScreenFrame = screenFrame
        model.beginSelection(at: point)
    }

    private func installInteractionMonitors() {
        removeInteractionMonitors()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            if event.keyCode == UInt16(kVK_Escape) {
                cancelSelection()
                return nil
            }
            return event
        }

        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.updateSelectionFromMouseLocation()
            return event
        }

        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.finishSelectionFromMouseLocation()
            return event
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelSelection()
            }
        }
    }

    private func removeInteractionMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private func updateSelectionFromMouseLocation() {
        guard let activeScreenFrame else {
            return
        }

        // 选区限制在起始屏幕内，避免多窗口跨屏拖拽时事件坐标失真。
        model.updateSelection(at: clampedMouseLocation(in: activeScreenFrame))
    }

    private func finishSelectionFromMouseLocation() {
        guard let activeScreenFrame else {
            return
        }

        finishSelection(at: clampedMouseLocation(in: activeScreenFrame))
    }

    private func clampedMouseLocation(in screenFrame: CGRect) -> CGPoint {
        let location = NSEvent.mouseLocation
        return CGPoint(
            x: min(max(location.x, screenFrame.minX), screenFrame.maxX),
            y: min(max(location.y, screenFrame.minY), screenFrame.maxY)
        )
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

private struct ScreenRegionSelectionPanelContext {
    let panel: ScreenRegionSelectionPanel
    let trackingView: ScreenRegionTrackingView
    let screenFrame: CGRect
}

private final class ScreenRegionTrackingView: NSView {
    var onBegin: (CGPoint) -> Void = { _ in }
    var onCancel: () -> Void = {}

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onBegin(event.locationInWindow)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }
}
