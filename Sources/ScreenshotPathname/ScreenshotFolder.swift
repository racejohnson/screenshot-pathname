import Foundation

/// Where screenshots land: a custom folder the user chose, or the macOS screenshot location.
enum ScreenshotFolder {
    /// Resolves the folder to watch. A custom folder wins even when missing, so the menu can
    /// show it as unavailable; the macOS location falls back to ~/Desktop, as screencapture does.
    static func resolve(
        custom: String?,
        system: String?,
        home: String,
        isDirectory: (URL) -> Bool
    ) -> URL {
        if let custom, !custom.isEmpty {
            return url(for: custom, home: home)
        }
        if let system, !system.isEmpty {
            let url = url(for: system, home: home)
            if isDirectory(url) { return url }
        }
        return url(for: "~/Desktop", home: home)
    }

    /// The `location` macOS screencapture saves to (set in Cmd-Shift-5 > Options), if any.
    static func systemLocation() -> String? {
        let domain = "com.apple.screencapture" as CFString
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue("location" as CFString, domain) as? String
    }

    static func current(custom: String?) -> URL {
        resolve(
            custom: custom,
            system: systemLocation(),
            home: NSHomeDirectory(),
            isDirectory: isDirectory
        )
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// `~/Screenshots` style, for the menu.
    static func displayPath(_ url: URL, home: String = NSHomeDirectory()) -> String {
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    private static func url(for path: String, home: String) -> URL {
        var path = path
        if path == "~" || path.hasPrefix("~/") {
            path = home + path.dropFirst()
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
}
