import AppKit
import QuartzCore
import SwiftUI

struct OverlayPanelTransition {
    let duration: TimeInterval
    let initialAlpha: CGFloat
    let finalAlpha: CGFloat
    let verticalOffset: CGFloat
    let scale: CGFloat
    let timingFunction: CAMediaTimingFunction

    static func present(offset: CGFloat) -> Self {
        Self(
            duration: 0.18,
            initialAlpha: 0,
            finalAlpha: 1,
            verticalOffset: -offset,
            scale: 0.98,
            timingFunction: CAMediaTimingFunction(name: .easeOut)
        )
    }

    static func dismiss(offset: CGFloat) -> Self {
        Self(
            duration: 0.18,
            initialAlpha: 1,
            finalAlpha: 0,
            verticalOffset: offset,
            scale: 0.98,
            timingFunction: CAMediaTimingFunction(name: .easeInEaseOut)
        )
    }

    func frame(fromVisibleFrame frame: CGRect) -> CGRect {
        let width = frame.width * scale
        return CGRect(
            x: frame.minX + (frame.width - width) / 2,
            y: frame.minY + verticalOffset,
            width: width,
            height: frame.height
        )
    }
}

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    private let panelWidth: CGFloat = 460
    private let confirmMinimumHeight: CGFloat = 188
    private let presentationOffset: CGFloat = 12
    private let mouseEventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    private let visualStyle = OverlayVisualStyle.current
    private let viewModel: OverlayViewModel
    private let backdropState = OverlayBackdropState()
    private let panel: OverlayPanel
    private let dismissalPolicy: OverlayDismissalPolicy
    private let sizingPolicy: OverlaySizingPolicy
    private let backdropSampler: OverlayBackdropSampling
    private var lastShownAt: TimeInterval?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var isClosing = false

    init(
        viewModel: OverlayViewModel = OverlayViewModel(),
        dismissalPolicy: OverlayDismissalPolicy = .default,
        sizingPolicy: OverlaySizingPolicy = .default,
        backdropSampler: OverlayBackdropSampling = DefaultOverlayBackdropSampler()
    ) {
        self.viewModel = viewModel
        self.dismissalPolicy = dismissalPolicy
        self.sizingPolicy = sizingPolicy
        self.backdropSampler = backdropSampler
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
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onCancel = { [weak self] in
            self?.closePanel()
        }
        let hostingView = TransparentHostingView(
            rootView: OverlayContentView(viewModel: viewModel, backdropState: backdropState)
        )
        if visualStyle.requiresTransparentWindow {
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

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
        refreshBackdropSample()
        presentPanel()
    }

    func closePanel() {
        guard panel.isVisible, isClosing == false else {
            return
        }

        isClosing = true
        let visibleFrame = panel.frame
        let transition = OverlayPanelTransition.dismiss(offset: presentationOffset)

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
        case let .result(text), let .error(text):
            targetHeight = sizingPolicy.height(for: text)
        case let .confirmLongText(text):
            targetHeight = max(sizingPolicy.height(for: text), confirmMinimumHeight)
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

        isClosing = false
        let targetFrame = panel.frame
        let transition = OverlayPanelTransition.present(offset: presentationOffset)
        let startingFrame = transition.frame(fromVisibleFrame: targetFrame)

        panel.alphaValue = transition.initialAlpha
        panel.setFrame(startingFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = transition.duration
            context.timingFunction = transition.timingFunction
            panel.animator().alphaValue = transition.finalAlpha
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

    private func refreshBackdropSample() {
        guard visualStyle == .liquidGlass else {
            backdropState.averageLuminance = nil
            return
        }

        backdropState.averageLuminance = backdropSampler.averageLuminance(behind: panel)
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

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }
}

@MainActor
final class OverlayBackdropState: ObservableObject {
    @Published var averageLuminance: CGFloat?
}

@MainActor
protocol OverlayBackdropSampling {
    func averageLuminance(behind panel: NSWindow) -> CGFloat?
}

@MainActor
struct DefaultOverlayBackdropSampler: OverlayBackdropSampling {
    private let sampleSize = CGSize(width: 20, height: 20)

    func averageLuminance(behind panel: NSWindow) -> CGFloat? {
        let sampleRect = samplingRect(for: panel.frame)
        guard sampleRect.isEmpty == false else {
            return nil
        }

        let image = captureImage(for: sampleRect, panel: panel)
        guard let image else {
            return nil
        }

        return averageLuminance(of: image)
    }

    private func captureImage(for sampleRect: CGRect, panel: NSWindow) -> CGImage? {
        let imageOptions: CGWindowImageOption = [.bestResolution]
        if panel.isVisible {
            return CGWindowListCreateImage(
                sampleRect,
                .optionOnScreenBelowWindow,
                CGWindowID(panel.windowNumber),
                imageOptions
            )
        }

        return CGWindowListCreateImage(
            sampleRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            imageOptions
        )
    }

    private func samplingRect(for panelFrame: CGRect) -> CGRect {
        // 取中部可读区域做真实采样，避免边缘高光把文字区判断冲淡。
        let insetX = panelFrame.width * 0.16
        let insetY = panelFrame.height * 0.18
        return panelFrame.insetBy(dx: insetX, dy: insetY).integral
    }

    private func averageLuminance(of image: CGImage) -> CGFloat? {
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(origin: .zero, size: sampleSize))

        var totalLuminance = 0.0
        var sampleCount = 0.0

        for pixelIndex in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[pixelIndex]) / 255.0
            let green = Double(pixels[pixelIndex + 1]) / 255.0
            let blue = Double(pixels[pixelIndex + 2]) / 255.0
            let alpha = Double(pixels[pixelIndex + 3]) / 255.0
            guard alpha > 0 else {
                continue
            }

            totalLuminance += ((0.2126 * red) + (0.7152 * green) + (0.0722 * blue)) * alpha
            sampleCount += alpha
        }

        guard sampleCount > 0 else {
            return nil
        }

        return CGFloat(totalLuminance / sampleCount)
    }
}
