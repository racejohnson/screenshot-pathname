import Foundation
import Testing
@testable import ScreenshotPathname

@Suite struct ScreenshotWatcherTests {
    @Test(.timeLimit(.minutes(1)))
    func yieldsNewScreenshotOnly() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotPathnameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let existing = directory.appendingPathComponent("Screenshot 0.png")
        try Data().write(to: existing)

        let screenshots = ScreenshotWatcher.screenshots(in: directory)
        // Saving over a screenshot that was already there looks like a fresh create.
        try Data([1]).write(to: existing, options: .atomic)
        try Data().write(to: directory.appendingPathComponent(".Screenshot temp.png"))
        try Data().write(to: directory.appendingPathComponent("notes.txt"))
        try Data().write(to: directory.appendingPathComponent("Screenshot 1.png"))

        let first = await withTaskGroup(of: URL?.self) { group in
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
        #expect(first?.lastPathComponent == "Screenshot 1.png")
    }
}
