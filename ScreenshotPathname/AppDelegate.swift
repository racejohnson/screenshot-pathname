import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private lazy var statusBarController = StatusBarController(appState: appState)
    private let bookmarkStore = FolderBookmarkStore()
    private let clipboardService = ClipboardService()
    private let notificationService = NotificationService()
    private let loginItemService = LoginItemService()

    private var folderWatcher: FolderWatcher?
    private var securityScopedFolderURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        wireMenuActions()
        syncStartAtLoginState()
        resolveAndBindInitialFolder()
        notificationService.requestAuthorizationIfNeeded()
        statusBarController.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopWatchingFolder()
    }

    private func wireMenuActions() {
        statusBarController.onToggleAutoCopy = { [weak self] isEnabled in
            self?.appState.autoCopyEnabled = isEnabled
        }

        statusBarController.onOpenFolder = { [weak self] in
            self?.openCurrentFolderInFinder()
        }

        statusBarController.onChooseFolder = { [weak self] in
            self?.chooseFolder()
        }

        statusBarController.onToggleStartAtLogin = { [weak self] isEnabled in
            self?.setStartAtLogin(isEnabled)
        }

        statusBarController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func syncStartAtLoginState() {
        appState.startAtLoginEnabled = loginItemService.currentStatus() == .enabled
    }

    private func resolveAndBindInitialFolder() {
        let resolvedURL = bookmarkStore.resolveFolderURL()
        bindFolder(resolvedURL)
    }

    private func bindFolder(_ folderURL: URL?) {
        stopWatchingFolder()

        guard let folderURL else {
            appState.currentFolderURL = nil
            appState.folderAvailable = false
            return
        }

        appState.currentFolderURL = folderURL

        guard folderExists(at: folderURL) else {
            appState.folderAvailable = false
            return
        }

        if folderURL.startAccessingSecurityScopedResource() {
            securityScopedFolderURL = folderURL
        }

        appState.folderAvailable = true
        startWatchingFolder(folderURL)
    }

    private func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func startWatchingFolder(_ folderURL: URL) {
        let watcher = FolderWatcher(folderURL: folderURL, debounceInterval: AppConfig.watcherDebounceInterval)
        watcher.onNewScreenshot = { [weak self] fileURL in
            self?.handleNewScreenshot(fileURL)
        }

        do {
            try watcher.start()
            folderWatcher = watcher
        } catch {
            appState.folderAvailable = false
            print("Failed to start folder watcher: \(error)")
        }
    }

    private func stopWatchingFolder() {
        folderWatcher?.stop()
        folderWatcher = nil

        if let securityScopedFolderURL {
            securityScopedFolderURL.stopAccessingSecurityScopedResource()
            self.securityScopedFolderURL = nil
        }
    }

    private func handleNewScreenshot(_ fileURL: URL) {
        guard appState.autoCopyEnabled else {
            return
        }

        clipboardService.copyPath(fileURL.path)
        notificationService.notifyCopied(path: fileURL.path)
    }

    private func openCurrentFolderInFinder() {
        guard appState.folderAvailable, let folderURL = appState.currentFolderURL else {
            return
        }

        NSWorkspace.shared.open(folderURL)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            do {
                try bookmarkStore.saveBookmark(for: selectedURL)
            } catch {
                print("Failed to save folder bookmark: \(error)")
            }

            bindFolder(selectedURL)
        }
    }

    private func setStartAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
        } catch {
            print("Failed to update start-at-login setting: \(error)")
        }

        appState.startAtLoginEnabled = loginItemService.currentStatus() == .enabled
    }
}
