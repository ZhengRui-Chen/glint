import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class ShortcutPanelController: NSObject, NSWindowDelegate {
    private static let panelWidth: CGFloat = 460
    private static let panelHeight: CGFloat = 284
    private static let presentationOffset: CGFloat = 12

    private let state: ShortcutPanelState
    private let panel: ShortcutPanelWindow
    private let hostingView: NSHostingView<ShortcutPanelView>
    private var isClosing = false

    init(shortcutSettings: ShortcutSettings = .default) {
        self.state = ShortcutPanelState(shortcutSettings: shortcutSettings)
        self.panel = ShortcutPanelWindow(
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
            rootView: ShortcutPanelView(
                state: state,
                onStartSelectionRecording: {},
                onStartClipboardRecording: {},
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
            self?.closePanel()
        }

        hostingView.rootView = makeRootView()
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func show() {
        if panel.isVisible {
            orderPanelFront()
            return
        }

        isClosing = false
        let targetFrame = panel.frame
        let transition = ShortcutPanelTransition.present(offset: Self.presentationOffset)
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
        let transition = ShortcutPanelTransition.dismiss(offset: Self.presentationOffset)

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

    func update(shortcutSettings: ShortcutSettings) {
        state.update(shortcutSettings: shortcutSettings)
    }

    private func makeRootView() -> ShortcutPanelView {
        ShortcutPanelView(
            state: state,
            onStartSelectionRecording: { [weak self] in
                self?.startRecording(.selection)
            },
            onStartClipboardRecording: { [weak self] in
                self?.startRecording(.clipboard)
            },
            onResetToDefaults: { [weak self] in
                self?.resetToDefaults()
            },
            onDone: { [weak self] in
                self?.closePanel()
            }
        )
    }

    private func startRecording(_ target: ShortcutTarget) {
        state.startRecording(for: target)
    }

    private func resetToDefaults() {
        state.resetToDefaults()
    }

    private func orderPanelFront() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class ShortcutPanelState: ObservableObject {
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    private var viewModel: ShortcutPanelViewModel

    init(shortcutSettings: ShortcutSettings) {
        self.viewModel = ShortcutPanelViewModel(shortcutSettings: shortcutSettings)
    }

    var selectionShortcutLabel: String {
        viewModel.selectionShortcutLabel
    }

    var clipboardShortcutLabel: String {
        viewModel.clipboardShortcutLabel
    }

    var recordingTarget: ShortcutTarget? {
        viewModel.recordingTarget
    }

    var statusMessage: String? {
        viewModel.statusMessage
    }

    var isRecordingSelectionShortcut: Bool {
        viewModel.isRecordingSelectionShortcut
    }

    var isRecordingClipboardShortcut: Bool {
        viewModel.isRecordingClipboardShortcut
    }

    func update(shortcutSettings: ShortcutSettings) {
        viewModel = ShortcutPanelViewModel(shortcutSettings: shortcutSettings)
        objectWillChange.send()
    }

    func startRecording(for target: ShortcutTarget) {
        viewModel.startRecording(for: target)
        objectWillChange.send()
    }

    func cancelRecording() {
        viewModel.cancelRecording()
        objectWillChange.send()
    }

    func applyRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) {
        viewModel.applyRecordedShortcut(shortcut)
        objectWillChange.send()
    }

    func resetToDefaults() {
        viewModel.resetToDefaults()
        objectWillChange.send()
    }
}

private struct ShortcutPanelTransition {
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
            scale: 0.985,
            timingFunction: CAMediaTimingFunction(name: .easeOut)
        )
    }

    static func dismiss(offset: CGFloat) -> Self {
        Self(
            duration: 0.18,
            initialAlpha: 1,
            finalAlpha: 0,
            verticalOffset: offset,
            scale: 0.985,
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

private final class ShortcutPanelWindow: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
