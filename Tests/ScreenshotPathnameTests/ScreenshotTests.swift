import CoreServices
import Foundation
import Testing
@testable import ScreenshotPathname

@Suite struct ScreenshotTests {
    let folder = "/Users/test/Screenshots"
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let created = FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemIsFile)
    let renamed = FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemIsFile)

    func isNew(
        _ name: String,
        flags: FSEventStreamEventFlags? = nil,
        in directory: String? = nil,
        age: TimeInterval? = 1
    ) -> Bool {
        Screenshot.isNew(
            path: (directory ?? folder) + "/" + name,
            flags: flags ?? created,
            in: folder,
            created: age.map { now.addingTimeInterval(-$0) },
            now: now
        )
    }

    @Test func acceptsRealScreenshotNames() {
        #expect(isNew("Screenshot 2026-11-08 at 1.23.45\u{202F}PM.png"))
        #expect(isNew("CleanShot-2026-11-08-130635.png"))
        #expect(isNew("CleanShot 2026-11-08 at 10.11.12 AM@2x.png", flags: renamed))
        #expect(isNew("CleanShot 2026-11-08 at 10.11.12-beautified.png"))
    }

    @Test func rejectsHiddenTempFile() {
        #expect(!isNew(".Screenshot 2026-11-08 at 1.23.45\u{202F}PM.png"))
    }

    @Test func rejectsRenameAway() {
        // The old name of a rename: the path is gone, so there is no creation date.
        #expect(!isNew("Screenshot.png", flags: renamed, age: nil))
    }

    @Test func rejectsSubfolder() {
        #expect(!isNew("Screenshot.png", in: folder + "/Archive"))
        #expect(!isNew("Screenshot.png", in: "/Users/test"))
    }

    @Test func rejectsOldFile() {
        #expect(!isNew("Screenshot.png", flags: renamed, age: 3600))
        #expect(!isNew("Screenshot.png", age: Screenshot.maxAge))
    }

    @Test func rejectsWrongExtension() {
        #expect(!isNew("Screen Recording 2026-11-08 at 1.23.45\u{202F}PM.mov"))
        #expect(!isNew("download.webp"))
        #expect(!isNew("notes.txt"))
        #expect(!isNew("png"))
    }

    @Test func acceptsUppercaseExtension() {
        #expect(isNew("IMG_0001.PNG"))
        #expect(isNew("photo.HeIc"))
    }

    @Test func requiresCreateOrRenameOfAFile() {
        #expect(!isNew("Screenshot.png", flags: FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemModified | kFSEventStreamEventFlagItemIsFile)))
        #expect(!isNew("Screenshot.png", flags: FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemIsDir)))
    }

    @Test func truncatesLongNamesInTheMiddle() {
        let name = "CleanShot 2026-11-08 at 10.11.12 AM@2x-beautified.png"
        let short = Screenshot.truncated(name)
        #expect(short.count == 40)
        #expect(short.hasPrefix("CleanShot 2026"))
        #expect(short.hasSuffix("beautified.png"))
        #expect(short.contains("…"))
        #expect(Screenshot.truncated("Short.png") == "Short.png")
    }

    @Test func findsNewestImage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotPathnameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for (index, name) in ["a.png", "b.jpg", "c.txt", ".d.png"].enumerated() {
            let url = directory.appendingPathComponent(name)
            try Data().write(to: url)
            try FileManager.default.setAttributes(
                [.creationDate: Date(timeIntervalSinceNow: Double(index * 60))], ofItemAtPath: url.path)
        }
        #expect(Screenshot.newest(in: directory)?.lastPathComponent == "b.jpg")
        #expect(Screenshot.newest(in: directory.appendingPathComponent("missing")) == nil)
    }
}
