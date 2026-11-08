import CoreServices
import Foundation

/// New screenshots in a folder, as they land.
enum ScreenshotWatcher {
    static func screenshots(in folder: URL) -> AsyncStream<URL> {
        AsyncStream { continuation in
            let watch = Watch(folder: folder, continuation: continuation)
            guard watch.start() else {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in watch.stop() }
        }
    }
}

/// One FSEvents stream. `@unchecked Sendable` because every mutable property is only touched
/// on `queue`, which is also the queue FSEvents calls back on.
private final class Watch: @unchecked Sendable {
    private let folder: String
    private let continuation: AsyncStream<URL>.Continuation
    private let queue = DispatchQueue(label: "com.racejohnson.ScreenshotPathname.watcher")
    private var stream: FSEventStreamRef?
    /// Paths in the folder when watching started, plus every path reported since. A file saved
    /// over in place (an atomic write looks like a fresh create) and the several events one
    /// capture produces stay quiet.
    private var seen: Set<String> = []

    init(folder: URL, continuation: AsyncStream<URL>.Continuation) {
        // FSEvents reports real paths (/private/var/…), so compare against the real path.
        self.folder = folder.withUnsafeFileSystemRepresentation { path in
            path.flatMap { realpath($0, nil) }.map { pointer in
                defer { free(pointer) }
                return String(cString: pointer)
            }
        } ?? folder.path
        self.continuation = continuation
    }

    func start() -> Bool {
        queue.sync {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            seen = Set(names.map { folder + "/" + $0 })

            // The stream retains the watch through `info` and releases it on FSEventStreamRelease.
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: { info in
                    info.map { _ = Unmanaged<Watch>.fromOpaque($0).retain() }
                    return info
                },
                release: { info in
                    info.map { Unmanaged<Watch>.fromOpaque($0).release() }
                },
                copyDescription: nil
            )
            // FileEvents: one event per file, not per directory. NoDefer: deliver the first
            // event right away instead of waiting out the latency.
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagNoDefer
            )
            guard let stream = FSEventStreamCreate(
                nil,
                { _, info, count, paths, flags, _ in
                    guard let info,
                          let paths = Unmanaged<NSArray>.fromOpaque(paths).takeUnretainedValue() as? [String]
                    else { return }
                    let watch = Unmanaged<Watch>.fromOpaque(info).takeUnretainedValue()
                    for index in 0..<min(count, paths.count) {
                        watch.handle(path: paths[index], flags: flags[index])
                    }
                },
                &context,
                [folder] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.1,
                flags
            ) else { return false }

            FSEventStreamSetDispatchQueue(stream, queue)
            guard FSEventStreamStart(stream) else {
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                return false
            }
            self.stream = stream
            return true
        }
    }

    func stop() {
        queue.async { [self] in
            guard let stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func handle(path: String, flags: FSEventStreamEventFlags) {
        let created = (try? FileManager.default.attributesOfItem(atPath: path))?[.creationDate] as? Date
        guard !seen.contains(path),
              Screenshot.isNew(path: path, flags: flags, in: folder, created: created, now: Date())
        else { return }
        // Remember only reported paths, so an event that doesn't qualify can't hide a later one.
        seen.insert(path)
        continuation.yield(URL(fileURLWithPath: path))
    }
}
