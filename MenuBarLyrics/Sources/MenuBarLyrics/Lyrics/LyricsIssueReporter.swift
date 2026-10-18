import Foundation
import LyricsCore

enum LyricsIssueReporter {
    static var recipient: String {
        Bundle.main.object(forInfoDictionaryKey: "FeedbackEmail") as? String ?? "FEEDBACK_EMAIL"
    }

    static func mailtoURL(
        recipient: String = recipient,
        track: NowPlayingTrack?,
        provider: String?,
        timing: TimedLyricDocument? = nil,
        selection: String? = nil,
        appVersion: String,
        language: AppLanguage = AppPreferences.language
    ) -> URL? {
        guard recipient.contains("@"), recipient != "FEEDBACK_EMAIL" else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        let diagnostics = timing.map { document in
            """
            Timing: \(document.timingFidelity.rawValue); word lines: \(document.lines.filter { !$0.segments.isEmpty }.count); end lines: \(document.lines.filter { $0.endTime != nil }.count)
            Source track ID: \(document.metadata.platformTrackID ?? "unavailable")
            First lyric timestamp: \(document.lines.first?.time ?? -1) s
            """
        } ?? ""
        let body = """
        \(L10n.text("Issue type: No lyrics / Wrong lyrics / Wrong song matched / Timing issue / Other", language: language))

        \(L10n.text("Current song", language: language)): \(track?.title ?? L10n.text("Unknown", language: language))
        \(L10n.text("Artist", language: language)): \(track?.artist ?? L10n.text("Unknown", language: language))
        \(L10n.text("Album", language: language)): \(track?.album ?? L10n.text("Unknown", language: language))
        \(L10n.text("Player source", language: language)): \(track?.playerSource.rawValue ?? L10n.text("Unknown", language: language))
        \(L10n.text("Lyrics provider", language: language)): \(provider ?? L10n.text("Unknown", language: language))
        \(L10n.text("NotchMuse version", language: language)): \(appVersion)
        \(selection ?? diagnostics)

        \(L10n.text("What happened?", language: language))

        """
        components.queryItems = [
            URLQueryItem(name: "subject", value: L10n.text("NotchMuse lyrics issue", language: language)),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
