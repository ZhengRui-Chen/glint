import AppKit
import SwiftUI

private enum APISettingsPanelLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 360
}

protocol ModelDiscoveryFetching {
    func fetchModels() async throws -> [String]
}

extension ModelDiscoveryClient: ModelDiscoveryFetching {}

struct APISettingsPanelTestingSnapshot: Equatable {
    let settings: APISettings
    let availableModels: [String]
    let isRefreshingModels: Bool
    let statusMessage: String?
}

@MainActor
final class APISettingsPanelController: NSObject, NSWindowDelegate {
    private let store: APISettingsStore
    private let makeDiscoveryClient: (APISettings) -> any ModelDiscoveryFetching
    private let onSave: (() -> Void)?
    private let state: APISettingsPanelViewState
    private let panel: APISettingsPanelWindow
    private let hostingView: NSHostingView<APISettingsPanelView>

    init(
        store: APISettingsStore = APISettingsStore(),
        makeDiscoveryClient: @escaping (APISettings) -> any ModelDiscoveryFetching = { settings in
            ModelDiscoveryClient(config: AppConfig(settings: settings))
        },
        onSave: (() -> Void)? = nil
    ) {
        self.store = store
        self.makeDiscoveryClient = makeDiscoveryClient
        self.onSave = onSave
        self.state = APISettingsPanelViewState(settings: store.load())
        self.panel = APISettingsPanelWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: APISettingsPanelLayout.width,
                height: APISettingsPanelLayout.height
            ),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.hostingView = NSHostingView(
            rootView: APISettingsPanelView(
                state: state,
                onRefreshModels: {},
                onCancel: {},
                onSave: {}
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
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onCancel = { [weak self] in
            self?.requestCancel()
        }

        hostingView.rootView = makeRootView()
        panel.contentView = hostingView
    }

    func show(anchorRect: CGRect? = nil) {
        state.update(
            settings: store.load(),
            availableModels: state.availableModels
        )

        let frame = resolvedTargetFrame(anchorRect: anchorRect)
        panel.setFrame(frame, display: false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func requestSave() {
        store.save(state.draftSettings)
        onSave?()
        closePanel()
    }

    func requestCancel() {
        closePanel()
    }

    func requestRefreshModels() {
        Task { @MainActor in
            try? await refreshModels()
        }
    }

    @discardableResult
    func refreshModels() async throws -> [String] {
        state.beginRefreshingModels()
        let settings = state.draftSettings

        do {
            let models = try await makeDiscoveryClient(settings).fetchModels()
            state.finishRefreshingModels(models)
            return models
        } catch {
            state.failRefreshingModels(L10n.apiSettingsModelRefreshFailed)
            throw error
        }
    }

    var testingSnapshot: APISettingsPanelTestingSnapshot {
        state.testingSnapshot
    }

    var isPanelVisibleForTesting: Bool {
        panel.isVisible
    }

    var testingPanelFrame: CGRect {
        panel.frame
    }

    func updateDraftForTesting(_ settings: APISettings) {
        state.updateDraft(settings)
    }

    private func closePanel() {
        panel.orderOut(nil)
    }

    private func makeRootView() -> APISettingsPanelView {
        APISettingsPanelView(
            state: state,
            onRefreshModels: { [weak self] in
                self?.requestRefreshModels()
            },
            onCancel: { [weak self] in
                self?.requestCancel()
            },
            onSave: { [weak self] in
                self?.requestSave()
            }
        )
    }

    private func resolvedTargetFrame(anchorRect: CGRect?) -> CGRect {
        let panelSize = CGSize(
            width: APISettingsPanelLayout.width,
            height: APISettingsPanelLayout.height
        )
        if let anchorRect {
            let screen = NSScreen.screens.first { $0.frame.intersects(anchorRect) } ?? NSScreen.main
            if let screen {
                return ShortcutPanelPlacement.frame(
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
}

@MainActor
final class APISettingsPanelViewState: ObservableObject {
    @Published var baseURLString: String
    @Published var apiKey: String
    @Published var model: String
    @Published private(set) var availableModels: [String]
    @Published private(set) var isRefreshingModels: Bool
    @Published private(set) var statusMessage: String?

    init(
        settings: APISettings,
        availableModels: [String] = []
    ) {
        baseURLString = settings.baseURLString
        apiKey = settings.apiKey
        model = settings.model
        self.availableModels = availableModels
        isRefreshingModels = false
        statusMessage = nil
    }

    var draftSettings: APISettings {
        APISettings(
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func update(
        settings: APISettings,
        availableModels: [String]
    ) {
        baseURLString = settings.baseURLString
        apiKey = settings.apiKey
        model = settings.model
        self.availableModels = availableModels
        isRefreshingModels = false
        statusMessage = nil
    }

    func updateDraft(_ settings: APISettings) {
        baseURLString = settings.baseURLString
        apiKey = settings.apiKey
        model = settings.model
    }

    func beginRefreshingModels() {
        isRefreshingModels = true
        statusMessage = nil
    }

    func finishRefreshingModels(_ models: [String]) {
        availableModels = models
        isRefreshingModels = false
        statusMessage = nil
    }

    func failRefreshingModels(_ message: String) {
        isRefreshingModels = false
        statusMessage = message
    }

    var testingSnapshot: APISettingsPanelTestingSnapshot {
        APISettingsPanelTestingSnapshot(
            settings: draftSettings,
            availableModels: availableModels,
            isRefreshingModels: isRefreshingModels,
            statusMessage: statusMessage
        )
    }
}

private struct APISettingsPanelView: View {
    @ObservedObject var state: APISettingsPanelViewState

    let onRefreshModels: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.apiSettingsTitle)
                    .font(.system(size: 20, weight: .semibold))
                Text(L10n.apiSettingsSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                field(title: L10n.apiBaseURL) {
                    TextField("", text: $state.baseURLString)
                        .textFieldStyle(.roundedBorder)
                }

                field(title: L10n.apiKey) {
                    SecureField("", text: $state.apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.model)
                        .font(.system(size: 12, weight: .medium))
                    APIModelComboBox(
                        text: $state.model,
                        options: state.availableModels
                    )
                    HStack(spacing: 8) {
                        Button(L10n.refreshModels, action: onRefreshModels)
                        if state.isRefreshingModels {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }

            if let statusMessage = state.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button(L10n.cancel, action: onCancel)
                Button(L10n.save, action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(
            width: APISettingsPanelLayout.width,
            height: APISettingsPanelLayout.height
        )
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            content()
        }
    }
}

private struct APIModelComboBox: NSViewRepresentable {
    @Binding var text: String
    let options: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.delegate = context.coordinator
        comboBox.addItems(withObjectValues: options)
        comboBox.stringValue = text
        return comboBox
    }

    func updateNSView(_ nsView: NSComboBox, context: Context) {
        if nsView.objectValues as? [String] != options {
            nsView.removeAllItems()
            nsView.addItems(withObjectValues: options)
        }

        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate, NSControlTextEditingDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else {
                return
            }
            text = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else {
                return
            }
            text = comboBox.stringValue
        }
    }
}

private final class APISettingsPanelWindow: NSPanel {
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
