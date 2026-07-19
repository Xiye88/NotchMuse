import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage = AppPreferences.language) -> String {
        bundle(for: language)?.localizedString(forKey: key, value: key, table: nil) ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg..., language: AppLanguage = AppPreferences.language) -> String {
        String(format: text(key, language: language), locale: Locale(identifier: language.rawValue), arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        let sourceResources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let paths = [
            Bundle.main.resourceURL?.appendingPathComponent("\(language.rawValue).lproj"),
            sourceResources.appendingPathComponent("\(language.rawValue).lproj")
        ].compactMap { $0?.path }
        return paths.lazy.compactMap(Bundle.init(path:)).first
    }
}
