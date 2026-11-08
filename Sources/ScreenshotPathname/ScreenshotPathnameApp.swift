import AppKit
import SwiftUI

@main
struct ScreenshotPathnameApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            AppMenu(model: model)
        } label: {
            MenuBarIcon(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarIcon: View {
    let model: AppModel

    var body: some View {
        icon.accessibilityLabel("Screenshot Pathname")
    }

    private var icon: Image {
        if model.justCopied { return Image(systemName: "checkmark") }
        let name = model.autoCopy ? "MenuBarIcon" : "MenuBarIconPaused"
        // 18 pt template images from Assets.car; SF Symbols when run outside the app bundle (swift run).
        if NSImage(named: name) != nil { return Image(name) }
        return Image(systemName: model.autoCopy ? "doc.on.clipboard" : "doc")
    }
}

private struct AppMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        Toggle("Copy New Screenshot Paths", isOn: $model.autoCopy)

        Divider()

        // When the folder is unavailable its title below already says so.
        if model.folderAvailable {
            if let latest = model.latest {
                Button("Latest: \(Screenshot.truncated(latest.lastPathComponent))") { model.copyLatest() }
            } else {
                Text("No Screenshots Yet")
            }
            Divider()
        }

        Menu(folderTitle) {
            Toggle("Use macOS Screenshot Location", isOn: Binding(
                get: { model.followsSystemLocation },
                set: { $0 ? model.followSystemLocation() : model.chooseFolder() }
            ))
            Button("Choose Folder…") { model.chooseFolder() }
            Divider()
            Button("Show in Finder") { model.showFolderInFinder() }
                .disabled(!model.folderAvailable)
        }
        Toggle("Notify on Copy", isOn: $model.notifyOnCopy)
        Toggle("Open at Login", isOn: Binding(
            get: { model.opensAtLogin },
            set: { model.setOpensAtLogin($0) }
        ))

        Divider()

        Button("Quit Screenshot Pathname") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var folderTitle: String {
        let path = ScreenshotFolder.displayPath(model.folder)
        return model.folderAvailable ? "Folder: \(path)" : "Folder Unavailable: \(path)"
    }
}
