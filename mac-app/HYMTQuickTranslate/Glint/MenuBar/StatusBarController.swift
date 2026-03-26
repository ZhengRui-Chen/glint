import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let viewModelProvider: () -> MenuBarViewModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(
        statusBar: NSStatusBar = .system,
        viewModelProvider: @escaping () -> MenuBarViewModel
    ) {
        self.viewModelProvider = viewModelProvider
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        configureStatusButton()

        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        let viewModel = viewModelProvider()

        menu.removeAllItems()

        let selectionItem = NSMenuItem(
            title: viewModel.translateSelectionLabel,
            action: #selector(handleTranslateSelection),
            keyEquivalent: ""
        )
        selectionItem.target = self
        selectionItem.isEnabled = true
        menu.addItem(selectionItem)

        let clipboardItem = NSMenuItem(
            title: viewModel.translateClipboardLabel,
            action: #selector(handleTranslateClipboard),
            keyEquivalent: ""
        )
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        menu.addItem(.separator())

        let selectionShortcutItem = NSMenuItem(
            title: viewModel.selectionShortcutLabel,
            action: #selector(handleRecordSelectionShortcut),
            keyEquivalent: ""
        )
        selectionShortcutItem.target = self
        menu.addItem(selectionShortcutItem)

        let clipboardShortcutItem = NSMenuItem(
            title: viewModel.clipboardShortcutLabel,
            action: #selector(handleRecordClipboardShortcut),
            keyEquivalent: ""
        )
        clipboardShortcutItem.target = self
        menu.addItem(clipboardShortcutItem)

        if let shortcutStatusLabel = viewModel.shortcutStatusLabel {
            let shortcutStatusItem = NSMenuItem(
                title: shortcutStatusLabel,
                action: nil,
                keyEquivalent: ""
            )
            shortcutStatusItem.isEnabled = false
            menu.addItem(shortcutStatusItem)
        }

        if viewModel.recordingTarget != nil {
            let cancelShortcutRecordingItem = NSMenuItem(
                title: viewModel.cancelShortcutRecordingLabel,
                action: #selector(handleCancelShortcutRecording),
                keyEquivalent: ""
            )
            cancelShortcutRecordingItem.target = self
            menu.addItem(cancelShortcutRecordingItem)
        }

        let permissionItem = NSMenuItem(
            title: viewModel.permissionLabel,
            action: nil,
            keyEquivalent: ""
        )
        permissionItem.isEnabled = false

        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: viewModel.quitLabel,
            action: #selector(handleQuit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.title = ""
        button.toolTip = AppBranding.displayName

        let image = NSImage(named: AppBranding.menuBarIconAssetName)
            ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppBranding.displayName)
        image?.isTemplate = true
        button.image = image
    }

    @objc
    private func handleTranslateSelection() {
        viewModelProvider().translateSelection()
    }

    @objc
    private func handleTranslateClipboard() {
        viewModelProvider().translateClipboard()
    }

    @objc
    private func handleRecordSelectionShortcut() {
        viewModelProvider().startRecordingSelectionShortcut()
    }

    @objc
    private func handleRecordClipboardShortcut() {
        viewModelProvider().startRecordingClipboardShortcut()
    }

    @objc
    private func handleCancelShortcutRecording() {
        viewModelProvider().cancelShortcutRecording()
    }

    @objc
    private func handleQuit() {
        viewModelProvider().quit()
    }
}
