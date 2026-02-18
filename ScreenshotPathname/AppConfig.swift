import Foundation

enum AppConfig {
    static let defaultScreenshotsPath = "/Users/racejohnson/Screenshots"
    static let watcherDebounceInterval: TimeInterval = 0.5
    static let shouldNotifyOnCopy = true
}

enum DefaultsKeys {
    static let autoCopyEnabled = "autoCopyEnabled"
    static let startAtLoginEnabled = "startAtLoginEnabled"
    static let selectedFolderBookmarkData = "selectedFolderBookmarkData"
}
