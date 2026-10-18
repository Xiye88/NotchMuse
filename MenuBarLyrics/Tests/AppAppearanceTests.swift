import AppKit

// Run with swiftc alongside App/AppAppearanceController.swift; uses a test executable's preferences.
@main
struct AppAppearanceTests {
    @MainActor
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        let light = NSAppearance(named: .aqua)!
        let dark = NSAppearance(named: .darkAqua)!
        check(AppAppearance.light.toggled(for: light) == .dark, "Light toggles to Dark")
        check(AppAppearance.light.toggled(for: dark) == .dark, "Explicit Light ignores a stale effective appearance")
        check(AppAppearance.dark.toggled(for: dark) == .light, "Dark toggles to Light")
        check(AppAppearance.dark.toggled(for: light) == .light, "Explicit Dark ignores a stale effective appearance")
        check(AppAppearance.system.toggled(for: light) == .dark, "System Light selects explicit Dark")
        check(AppAppearance.system.toggled(for: dark) == .light, "System Dark selects explicit Light")
        check(AppAppearance.system.toggled(for: NSAppearance(named: .accessibilityHighContrastDarkAqua)!) == .light,
              "System high contrast Dark selects explicit Light")

        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: AppAppearanceController.preferenceKey)
        let savedAppearance = NSApp.appearance
        defer {
            if let saved { defaults.set(saved, forKey: AppAppearanceController.preferenceKey) }
            else { defaults.removeObject(forKey: AppAppearanceController.preferenceKey) }
            NSApp.appearance = savedAppearance
        }
        for (mode, effective, expected) in [(AppAppearance.light, light, AppAppearance.dark),
                                            (.dark, dark, .light), (.system, light, .dark), (.system, dark, .light)] {
            AppAppearanceController.select(mode)
            AppAppearanceController.select(AppAppearanceController.selection.toggled(for: effective))
            check(AppAppearanceController.selection == expected, "Shortcut persists the selected mode")
            check(UserDefaults.standard.string(forKey: AppAppearanceController.preferenceKey) == expected.rawValue,
                  "Shortcut writes the existing appearance preference")
            NSApp.appearance = nil
            AppAppearanceController.apply()
            check(NSApp.appearance?.name == expected.appearance?.name, "Startup apply restores the saved mode")
        }
        print("AppAppearance: \(checks) checks passed")
    }
}
