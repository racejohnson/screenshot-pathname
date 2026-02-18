import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private let defaults: UserDefaults

    @Published var autoCopyEnabled: Bool {
        didSet {
            defaults.set(autoCopyEnabled, forKey: DefaultsKeys.autoCopyEnabled)
        }
    }

    @Published var startAtLoginEnabled: Bool {
        didSet {
            defaults.set(startAtLoginEnabled, forKey: DefaultsKeys.startAtLoginEnabled)
        }
    }

    @Published var currentFolderURL: URL?
    @Published var folderAvailable = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoCopyEnabled = defaults.object(forKey: DefaultsKeys.autoCopyEnabled) as? Bool ?? true
        self.startAtLoginEnabled = defaults.object(forKey: DefaultsKeys.startAtLoginEnabled) as? Bool ?? false
    }
}
