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
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        configureIfNeeded(
            defaults: .standard,
            bundleID: bundleID,
            isPreview: Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true,
            status: SMAppService.mainApp.status,
            register: { try SMAppService.mainApp.register() }
        )
    }

    static func configureIfNeeded(defaults: UserDefaults, bundleID: String, isPreview: Bool,
                                  status: SMAppService.Status, register: () throws -> Void) {
        guard !defaults.bool(forKey: initializedKey) else { return }
        // Never replace an existing system choice or opt Preview in automatically.
        guard !isPreview, status == .notRegistered else {
            markUserChoice(defaults: defaults)
            return
        }
        if defaults.object(forKey: pendingNewInstallKey) == nil {
            let existing = defaults.persistentDomain(forName: bundleID) ?? [:]
            defaults.set(shouldEnableByDefault(existingPreferences: existing, isPreview: isPreview),
                         forKey: pendingNewInstallKey)
        }
        guard defaults.bool(forKey: pendingNewInstallKey) else {
            markUserChoice(defaults: defaults)
            return
        }
        do {
            try register()
            markUserChoice(defaults: defaults)
        } catch {
            NSLog("NotchMuse: could not enable Launch at Login: %@", error.localizedDescription)
        }
    }

    static func markUserChoice(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: initializedKey)
        defaults.removeObject(forKey: pendingNewInstallKey)
    }
}
