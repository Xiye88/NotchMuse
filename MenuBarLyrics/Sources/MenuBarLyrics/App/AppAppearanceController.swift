import AppKit

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
enum AppAppearanceController {
    static let preferenceKey = "AppAppearance"

    static var selection: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .system
    }

    static func apply() {
        NSApp.appearance = selection.appearance
    }

    static func select(_ appearance: AppAppearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: preferenceKey)
        apply()
    }
}
