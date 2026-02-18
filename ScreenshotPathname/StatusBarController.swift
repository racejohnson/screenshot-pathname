import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private var cancellable: AnyCancellable?

    var onToggleAutoCopy: ((Bool) -> Void)?
    var onOpenFolder: (() -> Void)?
    var onChooseFolder: (() -> Void)?
    var onToggleStartAtLogin: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        bindState()
        refresh()
    }

    func refresh() {
        updateIcon()
        rebuildMenu()
    }

    private func bindState() {
        cancellable = appState.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    private func updateIcon() {
        let symbolName = appState.autoCopyEnabled ? "doc.on.clipboard" : "doc"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Screenshot path auto copy")
        statusItem.button?.imagePosition = .imageOnly
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let autoCopyItem = NSMenuItem(
            title: "Enable Auto Copy Path",
            action: #selector(toggleAutoCopy),
            keyEquivalent: ""
        )
        autoCopyItem.state = appState.autoCopyEnabled ? .on : .off
        autoCopyItem.target = self
        menu.addItem(autoCopyItem)

        let openFolderItem = NSMenuItem(
            title: "Open Screenshots Folder",
            action: #selector(openFolder),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        openFolderItem.isEnabled = appState.folderAvailable
        menu.addItem(openFolderItem)

        if !appState.folderAvailable {
            let chooseFolderItem = NSMenuItem(
                title: "Choose Folder…",
                action: #selector(chooseFolder),
                keyEquivalent: ""
            )
            chooseFolderItem.target = self
            menu.addItem(chooseFolderItem)
        }

        let startAtLoginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLogin),
            keyEquivalent: ""
        )
        startAtLoginItem.state = appState.startAtLoginEnabled ? .on : .off
        startAtLoginItem.target = self
        menu.addItem(startAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleAutoCopy() {
        onToggleAutoCopy?(!appState.autoCopyEnabled)
    }

    @objc private func openFolder() {
        onOpenFolder?()
    }

    @objc private func chooseFolder() {
        onChooseFolder?()
    }

    @objc private func toggleStartAtLogin() {
        onToggleStartAtLogin?(!appState.startAtLoginEnabled)
    }

    @objc private func quitApp() {
        onQuit?()
    }
}
