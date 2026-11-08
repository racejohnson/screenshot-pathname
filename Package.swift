// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenshotPathname",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenshotPathname",
            path: "Sources/ScreenshotPathname"
        ),
        .testTarget(
            name: "ScreenshotPathnameTests",
            dependencies: ["ScreenshotPathname"],
            path: "Tests/ScreenshotPathnameTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
