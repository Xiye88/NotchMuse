import Foundation

enum LyricsIssueReporter {
    static var recipient: String {
        Bundle.main.object(forInfoDictionaryKey: "FeedbackEmail") as? String ?? "FEEDBACK_EMAIL"
    }

    static func mailtoURL(
        recipient: String = recipient,
        track: NowPlayingTrack?,
        provider: String?,
        appVersion: String,
        language: AppLanguage = AppPreferences.language
    ) -> URL? {
        guard recipient.contains("@"), recipient != "FEEDBACK_EMAIL" else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        let body = """
        \(L10n.text("Issue type: No lyrics / Wrong lyrics / Wrong song matched / Timing issue / Other", language: language))

        \(L10n.text("Current song", language: language)): \(track?.title ?? L10n.text("Unknown", language: language))
        \(L10n.text("Artist", language: language)): \(track?.artist ?? L10n.text("Unknown", language: language))
        \(L10n.text("Album", language: language)): \(track?.album ?? L10n.text("Unknown", language: language))
        \(L10n.text("Player source", language: language)): \(track?.playerSource.rawValue ?? L10n.text("Unknown", language: language))
        \(L10n.text("Lyrics provider", language: language)): \(provider ?? L10n.text("Unknown", language: language))
        \(L10n.text("NotchMuse version", language: language)): \(appVersion)

        \(L10n.text("What happened?", language: language))

        """
        components.queryItems = [
            URLQueryItem(name: "subject", value: L10n.text("NotchMuse lyrics issue", language: language)),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
