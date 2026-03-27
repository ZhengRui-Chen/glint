import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class ShortcutPanelController: NSObject, NSWindowDelegate {
    private static let panelWidth: CGFloat = 460
    private static let panelHeight: CGFloat = 284
    private static let presentationOffset: CGFloat = 12

    let onAction: ((ShortcutPanelAction) -> Void)?

    private let state: ShortcutPanelViewState
    private let panel: ShortcutPanelWindow
    private let hostingView: NSHostingView<ShortcutPanelView>
    private var isClosing = false

    init(
        shortcutSettings: ShortcutSettings = .default,
        onAction: ((ShortcutPanelAction) -> Void)? = nil
    ) {
        self.state = ShortcutPanelViewState(shortcutSettings: shortcutSettings)
        self.onAction = onAction
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

    func requestStartRecording(for target: ShortcutTarget) {
        state.startRecording(for: target)
        emit(.startRecording(target))
    }

    func requestApplyRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) {
        guard let target = state.recordingTarget else {
            return
        }

        if case .saved = state.applyRecordedShortcut(shortcut) {
            emit(.saveRecordedShortcut(target: target, shortcut: shortcut))
        }
    }

    func requestResetToDefaults() {
        state.resetToDefaults()
        emit(.resetToDefaults)
    }

    func requestDone() {
        emit(.done)
        closePanel()
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
                self?.requestStartRecording(for: .selection)
            },
            onStartClipboardRecording: { [weak self] in
                self?.requestStartRecording(for: .clipboard)
            },
            onResetToDefaults: { [weak self] in
                self?.requestResetToDefaults()
            },
            onDone: { [weak self] in
                self?.requestDone()
            }
        )
    }

    private func emit(_ action: ShortcutPanelAction) {
        onAction?(action)
    }

    private func orderPanelFront() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class ShortcutPanelViewState: ObservableObject {
    @Published private(set) var selectionShortcutLabel: String
    @Published private(set) var clipboardShortcutLabel: String
    @Published private(set) var recordingTarget: ShortcutTarget?
    @Published private(set) var statusMessage: String?

    private var viewModel: ShortcutPanelViewModel

    init(shortcutSettings: ShortcutSettings) {
        self.viewModel = ShortcutPanelViewModel(shortcutSettings: shortcutSettings)
        self.selectionShortcutLabel = viewModel.selectionShortcutLabel
        self.clipboardShortcutLabel = viewModel.clipboardShortcutLabel
        self.recordingTarget = nil
        self.statusMessage = nil
    }

    var isRecordingSelectionShortcut: Bool {
        recordingTarget == .selection
    }

    var isRecordingClipboardShortcut: Bool {
        recordingTarget == .clipboard
    }

    func update(shortcutSettings: ShortcutSettings) {
        let preservedRecordingTarget = recordingTarget
        let preservedStatusMessage = statusMessage
        viewModel = ShortcutPanelViewModel(shortcutSettings: shortcutSettings)
        syncLabelsFromViewModel()
        recordingTarget = preservedRecordingTarget
        statusMessage = preservedStatusMessage
    }

    func startRecording(for target: ShortcutTarget) {
        viewModel.startRecording(for: target)
        recordingTarget = target
        statusMessage = "Press a new shortcut, or Esc to cancel"
    }

    func cancelRecording() {
        viewModel.cancelRecording()
        recordingTarget = nil
        statusMessage = nil
    }

    @discardableResult
    func applyRecordedShortcut(_ shortcut: GlobalHotkeyShortcut) -> ShortcutPanelApplyResult {
        guard let target = recordingTarget else {
            return .ignored
        }

        let recorder = ShortcutRecorder(existingSettings: viewModel.shortcutSettings)
        switch recorder.validate(shortcut, for: target) {
        case let .success(updatedSettings):
            viewModel = ShortcutPanelViewModel(shortcutSettings: updatedSettings)
            syncLabelsFromViewModel()
            recordingTarget = nil
            statusMessage = "Shortcut saved"
            return .saved(target: target)
        case .failure(.duplicateShortcut):
            recordingTarget = target
            statusMessage = "This shortcut is already used by Glint"
            return .failed(.duplicateShortcut)
        }
    }

    func resetToDefaults() {
        viewModel.resetToDefaults()
        syncLabelsFromViewModel()
        recordingTarget = nil
        statusMessage = "Defaults restored"
    }

    private func syncLabelsFromViewModel() {
        selectionShortcutLabel = viewModel.selectionShortcutLabel
        clipboardShortcutLabel = viewModel.clipboardShortcutLabel
    }
}

enum ShortcutPanelApplyResult: Equatable {
    case saved(target: ShortcutTarget)
    case failed(ShortcutSettingsError)
    case ignored
}

enum ShortcutPanelAction: Equatable {
    case startRecording(ShortcutTarget)
    case saveRecordedShortcut(target: ShortcutTarget, shortcut: GlobalHotkeyShortcut)
    case resetToDefaults
    case done
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
