import CoreServices
import Foundation

/// What counts as a screenshot, kept pure so every clause is unit tested.
enum Screenshot {
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif"]

    /// Moving or renaming an older file into the folder is not a new capture.
    static let maxAge: TimeInterval = 30

    /// A visible image file name. screencapture writes a hidden `.Screenshot…` file first.
    static func isImage(named name: String) -> Bool {
        !name.hasPrefix(".") && extensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Whether an FSEvents event announces a new screenshot in `folder`.
    /// - Parameter created: the file's creation date now, or nil when the path no longer
    ///   exists (the old name in a rename reports an event too).
    static func isNew(
        path: String,
        flags: FSEventStreamEventFlags,
        in folder: String,
        created: Date?,
        now: Date
    ) -> Bool {
        let appeared = FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed
        )
        let isFile = FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)
        guard flags & appeared != 0, flags & isFile != 0, let created else { return false }

        let url = URL(fileURLWithPath: path)
        // FSEvents is recursive; only direct children count.
        return url.deletingLastPathComponent().path == URL(fileURLWithPath: folder).path
            && isImage(named: url.lastPathComponent)
            && now.timeIntervalSince(created) < maxAge
    }

    /// The most recently created screenshot in `folder`: one directory listing.
    static func newest(in folder: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return files
            .filter { isImage(named: $0.lastPathComponent) }
            .map { ($0, (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast) }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// Shortens long names in the middle so the date and extension stay visible.
    static func truncated(_ name: String, limit: Int = 40) -> String {
        guard name.count > limit else { return name }
        let tail = limit / 2
        return name.prefix(limit - tail - 1) + "…" + name.suffix(tail)
    }
}
