import Foundation
import Testing
@testable import ScreenshotPathname

@Suite struct ScreenshotWatcherTests {
    @Test(.timeLimit(.minutes(1)))
    func yieldsNewScreenshotOnly() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let existing = directory.appendingPathComponent("Screenshot 0.png")
        try Data().write(to: existing)

        let screenshots = ScreenshotWatcher.screenshots(in: directory)
        // Saving over a screenshot that was already there looks like a fresh create.
        try Data([1]).write(to: existing, options: .atomic)
        try Data().write(to: directory.appendingPathComponent(".Screenshot temp.png"))
        try Data().write(to: directory.appendingPathComponent("notes.txt"))
        try Data().write(to: directory.appendingPathComponent("Screenshot 1.png"))

        #expect(await firstScreenshot(from: screenshots)?.lastPathComponent == "Screenshot 1.png")
    }

    /// CleanShot X saves by cloning a file into the folder. FSEvents reports that as two
    /// events: first with only IsFile|Cloned, then again with Created.
    @Test(.timeLimit(.minutes(1)))
    func yieldsClonedScreenshot() async throws {
        let directory = try makeDirectory()
        let source = try makeDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: source)
        }
        let original = source.appendingPathComponent("capture.png")
        try Data([1, 2, 3]).write(to: original)

        let screenshots = ScreenshotWatcher.screenshots(in: directory)
        // copyItem clones on APFS, just like CleanShot's save.
        try FileManager.default.copyItem(at: original, to: directory.appendingPathComponent("CleanShot-1.png"))

        #expect(await firstScreenshot(from: screenshots)?.lastPathComponent == "CleanShot-1.png")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotPathnameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// The first screenshot the stream yields, or nil after 2 s.
    private func firstScreenshot(from screenshots: AsyncStream<URL>) async -> URL? {
        await withTaskGroup(of: URL?.self) { group in
            group.addTask {
                var iterator = screenshots.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
