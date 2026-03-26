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
        statusItem.button?.title = "HY"
        statusItem.button?.toolTip = "HYMT Quick Translate"

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
        selectionItem.isEnabled = viewModel.permissionStatus == .granted
        menu.addItem(selectionItem)

        let clipboardItem = NSMenuItem(
            title: viewModel.translateClipboardLabel,
            action: #selector(handleTranslateClipboard),
            keyEquivalent: ""
        )
        clipboardItem.target = self
        menu.addItem(clipboardItem)

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

    @objc
    private func handleTranslateSelection() {
        viewModelProvider().translateSelection()
    }

    @objc
    private func handleTranslateClipboard() {
        viewModelProvider().translateClipboard()
    }

    @objc
    private func handleQuit() {
        viewModelProvider().quit()
    }
}
