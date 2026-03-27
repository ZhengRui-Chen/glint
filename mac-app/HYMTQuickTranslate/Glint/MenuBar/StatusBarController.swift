import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let viewModelProvider: () -> MenuBarViewModel
    private let onMenuWillOpen: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(
        statusBar: NSStatusBar = .system,
        onMenuWillOpen: @escaping () -> Void = {},
        viewModelProvider: @escaping () -> MenuBarViewModel
    ) {
        self.viewModelProvider = viewModelProvider
        self.onMenuWillOpen = onMenuWillOpen
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        configureStatusButton()

        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        onMenuWillOpen()
        rebuildMenu()
    }

    func refreshMenu() {
        rebuildMenu()
    }

    var statusButtonFrameInScreen: CGRect? {
        guard
            let button = statusItem.button,
            let window = button.window
        else {
            return nil
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(buttonFrameInWindow)
    }

    private func rebuildMenu() {
        let viewModel = viewModelProvider()

        menu.removeAllItems()

        let backendHeadlineItem = NSMenuItem(
            title: viewModel.backendHeadline,
            action: nil,
            keyEquivalent: ""
        )
        backendHeadlineItem.isEnabled = false
        menu.addItem(backendHeadlineItem)

        let backendDetailItem = NSMenuItem(
            title: viewModel.backendDetail,
            action: nil,
            keyEquivalent: ""
        )
        backendDetailItem.isEnabled = false
        menu.addItem(backendDetailItem)

        menu.addItem(.separator())

        let apiSettingsItem = NSMenuItem(
            title: viewModel.apiSettingsLabel,
            action: #selector(handleOpenAPISettings),
            keyEquivalent: ""
        )
        apiSettingsItem.target = self
        menu.addItem(apiSettingsItem)

        let refreshStatusItem = NSMenuItem(
            title: viewModel.refreshStatusLabel,
            action: #selector(handleRefreshStatus),
            keyEquivalent: ""
        )
        refreshStatusItem.target = self
        refreshStatusItem.isEnabled = viewModel.canRefreshStatus
        menu.addItem(refreshStatusItem)

        menu.addItem(.separator())

        let selectionItem = NSMenuItem(
            title: viewModel.translateSelectionLabel,
            action: #selector(handleTranslateSelection),
            keyEquivalent: ""
        )
        selectionItem.target = self
        selectionItem.isEnabled = viewModel.canTranslateSelection
        menu.addItem(selectionItem)

        let clipboardItem = NSMenuItem(
            title: viewModel.translateClipboardLabel,
            action: #selector(handleTranslateClipboard),
            keyEquivalent: ""
        )
        clipboardItem.target = self
        clipboardItem.isEnabled = viewModel.canTranslateClipboard
        menu.addItem(clipboardItem)

        let ocrItem = NSMenuItem(
            title: viewModel.translateOCRLabel,
            action: #selector(handleTranslateOCR),
            keyEquivalent: ""
        )
        ocrItem.target = self
        ocrItem.isEnabled = viewModel.canTranslateOCR
        menu.addItem(ocrItem)

        menu.addItem(.separator())

        let keyboardShortcutsItem = NSMenuItem(
            title: viewModel.keyboardShortcutsLabel,
            action: #selector(handleOpenKeyboardShortcuts),
            keyEquivalent: ""
        )
        keyboardShortcutsItem.target = self
        menu.addItem(keyboardShortcutsItem)

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
        image?.size = NSSize(width: 20, height: 20)
        button.imageScaling = .scaleProportionallyDown
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
    private func handleTranslateOCR() {
        viewModelProvider().translateOCR()
    }

    @objc
    private func handleOpenAPISettings() {
        viewModelProvider().openAPISettings()
    }

    @objc
    private func handleRefreshStatus() {
        viewModelProvider().refreshStatus()
    }

    @objc
    private func handleOpenKeyboardShortcuts() {
        viewModelProvider().openKeyboardShortcuts()
    }

    @objc
    private func handleQuit() {
        viewModelProvider().quit()
    }
}
