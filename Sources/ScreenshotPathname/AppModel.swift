import AppKit
import Observation
import os
import ServiceManagement
import UserNotifications

private let log = Logger(subsystem: "com.racejohnson.ScreenshotPathname", category: "app")

@MainActor
@Observable
final class AppModel {
    var autoCopy: Bool {
        didSet { defaults.set(autoCopy, forKey: Keys.autoCopy) }
    }

    var notifyOnCopy: Bool {
        didSet {
            defaults.set(notifyOnCopy, forKey: Keys.notifyOnCopy)
            if notifyOnCopy, !oldValue { Task { await requestNotifications() } }
        }
    }

    private var customFolderPath: String? {
        didSet { defaults.set(customFolderPath, forKey: Keys.customFolderPath) }
    }

    private(set) var folder: URL
    private(set) var folderAvailable = false
    private(set) var latest: URL?
    private(set) var justCopied = false
    private(set) var opensAtLogin = false

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var copyTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    private enum Keys {
        static let autoCopy = "autoCopyEnabled"
        static let notifyOnCopy = "notifyOnCopy"
        static let customFolderPath = "customFolderPath"
        static let openAtLogin = "openAtLogin"
    }

    init() {
        defaults.register(defaults: [Keys.autoCopy: true, Keys.notifyOnCopy: false])
        // Left over from version 1: its login choice moves to the new key, and the folder is
        // now a plain path because the app is not sandboxed.
        if let legacy = defaults.object(forKey: "startAtLoginEnabled") as? Bool {
            defaults.set(legacy, forKey: Keys.openAtLogin)
        }
        defaults.removeObject(forKey: "startAtLoginEnabled")
        defaults.removeObject(forKey: "selectedFolderBookmarkData")

        autoCopy = defaults.bool(forKey: Keys.autoCopy)
        notifyOnCopy = defaults.bool(forKey: Keys.notifyOnCopy)
        let custom = defaults.string(forKey: Keys.customFolderPath)
        customFolderPath = custom
        folder = ScreenshotFolder.current(custom: custom)

        restoreLoginItem()
        refresh()
        Task { await pollForChanges() }
    }

    // MARK: Folder

    var followsSystemLocation: Bool { customFolderPath == nil }

    func followSystemLocation() {
        customFolderPath = nil
        refresh()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        panel.prompt = "Watch Folder"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customFolderPath = url.path
        refresh()
    }

    func showFolderInFinder() {
        NSWorkspace.shared.open(folder)
    }

    /// The macOS location can change at any time (Cmd-Shift-5 > Options) and drives come and
    /// go, so re-read both every few seconds; the watcher restarts only when something changed.
    private func pollForChanges() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            refresh()
        }
    }

    private func refresh() {
        let loginEnabled = SMAppService.mainApp.status == .enabled
        // Turned off in System Settings while running: that is the user's choice now.
        if opensAtLogin, !loginEnabled { defaults.set(false, forKey: Keys.openAtLogin) }
        opensAtLogin = loginEnabled
        forgetLatestIfDeleted()

        let resolved = ScreenshotFolder.current(custom: customFolderPath)
        let available = ScreenshotFolder.isDirectory(resolved)
        guard resolved != folder || available != folderAvailable else { return }

        folder = resolved
        folderAvailable = available
        watchTask?.cancel()
        watchTask = nil
        latest = available ? Screenshot.newest(in: resolved) : nil
        guard available else {
            log.notice("Folder unavailable: \(resolved.path, privacy: .public)")
            return
        }

        log.info("Watching \(resolved.path, privacy: .public)")
        let screenshots = ScreenshotWatcher.screenshots(in: resolved)
        watchTask = Task {
            for await url in screenshots {
                handleNewScreenshot(url)
            }
        }
    }

    /// Screenshots are often deleted right after capture; fall back to the next newest.
    private func forgetLatestIfDeleted() {
        guard let latest, !FileManager.default.fileExists(atPath: latest.path) else { return }
        self.latest = folderAvailable ? Screenshot.newest(in: folder) : nil
    }

    // MARK: Copying

    /// Files that land together (one per display) settle on the newest with a single copy.
    private func handleNewScreenshot(_ url: URL) {
        latest = url
        copyTask?.cancel()
        copyTask = Task {
            // Let the capture tool finish writing the file and its own clipboard work first.
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled, autoCopy, FileManager.default.fileExists(atPath: url.path) else { return }
            copy(url)
        }
    }

    func copyLatest() {
        forgetLatestIfDeleted()
        if let latest { copy(latest) }
    }

    private func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        log.info("Copied \(url.lastPathComponent, privacy: .public)")

        justCopied = true
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { justCopied = false }
        }

        if notifyOnCopy { postNotification(for: url) }
    }

    // MARK: Notifications

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .denied {
            // Denied earlier, so the system will not ask again: send the user to Settings instead.
            notifyOnCopy = false
            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        } else if (try? await center.requestAuthorization(options: [.alert])) != true {
            notifyOnCopy = false
        }
    }

    private func postNotification(for url: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot path copied"
        content.body = url.lastPathComponent
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Login item

    /// macOS can drop the login item when the app is rebuilt (a new ad-hoc signature) or
    /// moved, so the user's choice lives in defaults and is restored at launch. A login item
    /// turned off in System Settings is not restored: that is recorded by `refresh()`.
    private func restoreLoginItem() {
        let service = SMAppService.mainApp
        guard defaults.bool(forKey: Keys.openAtLogin), service.status == .notRegistered else { return }
        do {
            try service.register()
            log.info("Restored Open at Login")
        } catch {
            log.error("Restoring Open at Login failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.openAtLogin)
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            log.error("Open at Login failed: \(error.localizedDescription, privacy: .public)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        opensAtLogin = service.status == .enabled
    }
}
