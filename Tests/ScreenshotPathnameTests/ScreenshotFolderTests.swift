import Foundation
import Testing
@testable import ScreenshotPathname

@Suite struct ScreenshotFolderTests {
    let home = "/Users/test"

    func resolve(custom: String? = nil, system: String? = nil, existing: Set<String> = []) -> String {
        ScreenshotFolder.resolve(custom: custom, system: system, home: home) {
            existing.contains($0.path)
        }.path
    }

    @Test func followsSystemLocation() {
        #expect(resolve(system: "/Users/test/Screenshots", existing: ["/Users/test/Screenshots"])
            == "/Users/test/Screenshots")
    }

    @Test func expandsTildeAndStandardizes() {
        #expect(resolve(system: "~/Screenshots/", existing: ["/Users/test/Screenshots"])
            == "/Users/test/Screenshots")
        #expect(resolve(system: "/Users/test/./Pictures/../Screenshots", existing: ["/Users/test/Screenshots"])
            == "/Users/test/Screenshots")
        #expect(resolve(custom: "~/Shots") == "/Users/test/Shots")
    }

    @Test func fallsBackToDesktop() {
        #expect(resolve() == "/Users/test/Desktop")
        #expect(resolve(system: "") == "/Users/test/Desktop")
        #expect(resolve(system: "/Volumes/Gone/Screenshots") == "/Users/test/Desktop")
    }

    @Test func customFolderWinsEvenWhenMissing() {
        #expect(resolve(custom: "/Volumes/Drive/Shots", system: "/Users/test/Screenshots",
                        existing: ["/Users/test/Screenshots"]) == "/Volumes/Drive/Shots")
    }

    @Test func emptyCustomFollowsSystem() {
        #expect(resolve(custom: "", system: "~/Screenshots", existing: ["/Users/test/Screenshots"])
            == "/Users/test/Screenshots")
    }

    @Test func displayPathAbbreviatesHome() {
        #expect(ScreenshotFolder.displayPath(URL(fileURLWithPath: "/Users/test/Screenshots"), home: home)
            == "~/Screenshots")
        #expect(ScreenshotFolder.displayPath(URL(fileURLWithPath: "/Users/tester"), home: home)
            == "/Users/tester")
        #expect(ScreenshotFolder.displayPath(URL(fileURLWithPath: "/Volumes/Shots"), home: home)
            == "/Volumes/Shots")
    }
}
