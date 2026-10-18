import Foundation
import LyricsCore

/// Source evidence is retained independently of the player's identity.
struct LyricsCandidate: Equatable, Sendable {
    let document: TimedLyricDocument
    let provider: String
    let sourcePlatform: String?
    let sourceTrackID: String?
    let sourceTitle: String
    let sourceArtist: String
    let sourceAlbum: String?
    let sourceDuration: Double?
    let sourceISRC: String?
    let matcherScore: Int?
    var elapsed: Double
    /// Only the guarded live NetEase path sets this, never a search adapter.
    let liveIdentityVerified: Bool

    init(document: TimedLyricDocument, provider: String, sourcePlatform: String? = nil,
         sourceTrackID: String? = nil, sourceTitle: String, sourceArtist: String,
         sourceAlbum: String? = nil, sourceDuration: Double? = nil, sourceISRC: String? = nil,
         matcherScore: Int? = nil, elapsed: Double = 0, liveIdentityVerified: Bool = false) {
        self.document = document; self.provider = provider; self.sourcePlatform = sourcePlatform
        self.sourceTrackID = sourceTrackID; self.sourceTitle = sourceTitle; self.sourceArtist = sourceArtist
        self.sourceAlbum = sourceAlbum; self.sourceDuration = sourceDuration; self.sourceISRC = sourceISRC
        self.matcherScore = matcherScore; self.elapsed = elapsed; self.liveIdentityVerified = liveIdentityVerified
    }
}

/// Presentation formatting does not create identity; the source provenance still
/// decides whether a valid ISRC can enter Tier B.
enum RecordingISRC {
    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let compact = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: "-", with: "")
        return compact.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil ? compact : nil
    }
}

struct LyricsSelectionContext: Sendable {
    let track: SpotifyTrack
    let playerSource: String?
    let nativeTrackID: String?
    let isrc: String?

    var platform: String? {
        switch playerSource?.lowercased() {
        case "spotify": return "spotify"
        case "neteasemusic", "netease", "netease music", "netease cloud music": return "netease"
        case "qqmusic", "qq music", "qq": return "qq"
        case "sodamusic", "soda music", "soda": return "soda"
        case "applemusic", "apple music", "apple": return "apple"
        default: return playerSource?.lowercased()
        }
    }
    var cacheKey: String {
        ["selection-v4-recall", platform ?? "unspecified", nativeTrackID ?? "", RecordingISRC.normalized(isrc) ?? isrc ?? "",
         track.name, track.artist, track.album, String(track.duration)].joined(separator: "\u{1F}")
    }
}
