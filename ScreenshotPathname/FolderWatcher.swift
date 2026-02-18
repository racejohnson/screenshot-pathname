import Darwin
import Foundation

final class FolderWatcher {
    private struct Candidate {
        let url: URL
        let date: Date
        let identity: String
    }

    private let folderURL: URL
    private let debounceInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.racejohnson.screenshotpathname.folderwatcher")
    private let fileManager = FileManager.default
    private let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var pendingWorkItem: DispatchWorkItem?
    private var lastSeenIdentity: String?
    private var lastSeenDate: Date = .distantPast

    var onNewScreenshot: ((URL) -> Void)?

    init(folderURL: URL, debounceInterval: TimeInterval = AppConfig.watcherDebounceInterval) {
        self.folderURL = folderURL
        self.debounceInterval = debounceInterval
    }

    deinit {
        stop()
    }

    func start() throws {
        stop()

        fileDescriptor = open(folderURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw NSError(
                domain: "FolderWatcher",
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "Failed to open watched folder: \(folderURL.path)"]
            )
        }

        let eventMask: DispatchSource.FileSystemEvent = [.write, .rename, .extend, .attrib, .delete]
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: queue
        )

        newSource.setEventHandler { [weak self] in
            self?.scheduleDebouncedScan()
        }

        newSource.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source = newSource
        establishBaseline()
        newSource.resume()
    }

    func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        if let source {
            source.cancel()
            self.source = nil
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func scheduleDebouncedScan() {
        pendingWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.handleDebouncedScan()
        }

        pendingWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func establishBaseline() {
        guard let latest = latestScreenshotCandidate() else {
            lastSeenIdentity = nil
            lastSeenDate = .distantPast
            return
        }

        lastSeenIdentity = latest.identity
        lastSeenDate = latest.date
    }

    private func handleDebouncedScan() {
        guard let latest = latestScreenshotCandidate() else {
            return
        }

        if latest.identity == lastSeenIdentity {
            return
        }

        if latest.date < lastSeenDate {
            return
        }

        lastSeenIdentity = latest.identity
        if latest.date > lastSeenDate {
            lastSeenDate = latest.date
        }

        DispatchQueue.main.async { [weak self] in
            self?.onNewScreenshot?(latest.url)
        }
    }

    private func latestScreenshotCandidate() -> Candidate? {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileResourceIdentifierKey
        ]

        guard let files = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var candidates = [Candidate]()

        for file in files {
            let fileExtension = file.pathExtension.lowercased()
            guard allowedExtensions.contains(fileExtension) else {
                continue
            }

            guard let values = try? file.resourceValues(forKeys: keys) else {
                continue
            }

            if values.isRegularFile == false {
                continue
            }

            let timestamp = values.creationDate ?? values.contentModificationDate ?? .distantPast
            let identity = values.fileResourceIdentifier.map { String(describing: $0) } ?? file.path

            candidates.append(Candidate(url: file, date: timestamp, identity: identity))
        }

        return candidates.max { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.url.path < rhs.url.path
            }

            return lhs.date < rhs.date
        }
    }
}
