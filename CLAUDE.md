# CLAUDE.md

## Project Overview

Screenshot Pathname is a macOS menu bar app (Swift 6, macOS 14+) that copies the POSIX path of each new screenshot to the clipboard. SwiftPM only, no Xcode project. Bundle ID `com.racejohnson.ScreenshotPathname` (keep it: it carries the owner's defaults, login item and notification permission).

## Commands

- **Build**: `swift build`
- **Test**: `swift test` (single suite: `swift test --filter ScreenshotTests`)
- **Build app**: `scripts/build-app.sh` → `build/ScreenshotPathname.app`
- **Install**: `scripts/install.sh` (builds, replaces `/Applications/ScreenshotPathname.app`, relaunches)
- **Icon preview**: `scripts/icon-preview.sh` (renders `AppIcon.icon` in every appearance and at Finder sizes into `build/icon-preview/`)

Don't launch a second copy while the installed app runs: both would copy paths.

## Architecture

```
Sources/ScreenshotPathname/
├── ScreenshotPathnameApp.swift  # @main, MenuBarExtra (.menu style), menu and icon
├── AppModel.swift               # @MainActor @Observable state: settings, watching, copying, login item
├── ScreenshotFolder.swift       # which folder: custom path or macOS screencapture location (pure resolve)
├── Screenshot.swift             # what counts as a new screenshot (pure rule), newest-file scan
└── ScreenshotWatcher.swift      # FSEvents stream → AsyncStream<URL>
Resources/
├── Info.plist                   # real values, copied as-is into the bundle
├── AppIcon.icon                 # app icon (Icon Composer), compiled by actool
└── Assets.xcassets              # MenuBarIcon / MenuBarIconPaused template images
```

The model re-resolves the folder every 5 s and restarts the watcher only when the folder or its availability changes. New screenshots are copied 0.4 s after detection so capture tools finish first.

## Conventions

- One `@Observable` model, no Combine, no AppDelegate, no protocols for single implementations.
- Keep decisions in pure functions (`ScreenshotFolder.resolve`, `Screenshot.isNew`) and test them with Swift Testing.
- Log with `os.Logger` (subsystem = bundle ID), never `print`. No force unwraps.
- Comments only where a reader needs the why.
- UserDefaults keys: `autoCopyEnabled`, `notifyOnCopy`, `customFolderPath`.
