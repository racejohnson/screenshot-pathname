import Foundation

final class FolderBookmarkStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func resolveFolderURL() -> URL? {
        if let bookmarkData = defaults.data(forKey: DefaultsKeys.selectedFolderBookmarkData) {
            var isStale = false

            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    try saveBookmark(for: resolvedURL)
                }

                return resolvedURL
            } catch {
                defaults.removeObject(forKey: DefaultsKeys.selectedFolderBookmarkData)
            }
        }

        return URL(fileURLWithPath: AppConfig.defaultScreenshotsPath, isDirectory: true)
    }

    func saveBookmark(for folderURL: URL) throws {
        let bookmarkData = try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        defaults.set(bookmarkData, forKey: DefaultsKeys.selectedFolderBookmarkData)
    }

    func clearBookmark() {
        defaults.removeObject(forKey: DefaultsKeys.selectedFolderBookmarkData)
    }
}
