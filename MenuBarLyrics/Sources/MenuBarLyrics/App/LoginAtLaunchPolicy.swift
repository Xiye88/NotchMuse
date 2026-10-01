import Foundation
import ServiceManagement

@MainActor
enum LoginAtLaunchPolicy {
    static let initializedKey = "LaunchAtLoginInitialized"
    static let pendingNewInstallKey = "LaunchAtLoginPendingNewInstall"

    static func shouldEnableByDefault(existingPreferences: [String: Any], isPreview: Bool) -> Bool {
        !isPreview && existingPreferences.isEmpty
    }

    static func configureIfNeeded() {
        guard Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool != true,
              let bundleID = Bundle.main.bundleIdentifier else { return }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: initializedKey) else { return }
        if defaults.object(forKey: pendingNewInstallKey) == nil {
            let existing = defaults.persistentDomain(forName: bundleID) ?? [:]
            defaults.set(shouldEnableByDefault(existingPreferences: existing, isPreview: false),
                         forKey: pendingNewInstallKey)
        }
        guard defaults.bool(forKey: pendingNewInstallKey) else {
            defaults.set(true, forKey: initializedKey)
            return
        }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: initializedKey)
            defaults.removeObject(forKey: pendingNewInstallKey)
        } catch {
            NSLog("NotchMuse: could not enable Launch at Login: %@", error.localizedDescription)
        }
    }

    static func markUserChoice() {
        UserDefaults.standard.set(true, forKey: initializedKey)
        UserDefaults.standard.removeObject(forKey: pendingNewInstallKey)
    }
}
