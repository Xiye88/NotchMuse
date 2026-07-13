import Foundation

enum TrackMatcher {
    static let acceptanceThreshold = 82

    struct Candidate {
        let title: String
        let artists: [String]
        let durationMs: Int
    }

    static func score(_ track: SpotifyTrack, candidate: Candidate) -> Int {
        let sourceTitle = parsedTitle(track.name)
        let candidateTitle = parsedTitle(candidate.title)
        let durationDifference = abs(track.duration - Double(candidate.durationMs) / 1000)

        guard sourceTitle.name == candidateTitle.name,
              sourceTitle.versions == candidateTitle.versions,
              durationDifference <= 12 else { return 0 }

        let sourceArtists = artistKeys([track.artist])
        let candidateArtists = artistKeys(candidate.artists)
        let artistsMatch = artistsMatch(source: sourceArtists.members, candidate: candidateArtists.members, primary: sourceArtists.primary)
            || artistsMatch(source: sourceArtists.group, candidate: candidateArtists.group, primary: sourceArtists.primary)
        let artistScore = artistsMatch ? 30 : 0
        let durationScore: Int
        switch durationDifference {
        case ...2: durationScore = 15
        case ...5: durationScore = 11
        case ...8: durationScore = 7
        default: durationScore = 3
        }
        return 55 + artistScore + durationScore
    }

    static func bestMatchIndex(for track: SpotifyTrack, candidates: [Candidate]) -> Int? {
        let ranked = candidates.enumerated()
            .map { (index: $0.offset, score: score(track, candidate: $0.element)) }
            .sorted { $0.score > $1.score }
        guard let best = ranked.first, best.score >= acceptanceThreshold else { return nil }
        guard ranked.count < 2 || best.score - ranked[1].score >= 6 else { return nil }
        return best.index
    }

    private static func parsedTitle(_ title: String) -> (name: String, versions: Set<String>) {
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        var name = folded
        for pattern in [
            #"[\(\[].*?\b(feat\.?|ft\.?|featuring)\b.*?[\)\]]"#,
            #"\s+\b(feat\.?|ft\.?|featuring)\b.*$"#
        ] {
            name = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        let versions = Set(["live", "remix", "acoustic", "instrumental"].filter {
            name.range(of: "\\b\($0)\\b", options: .regularExpression) != nil
        })
        for pattern in [
            #"[\(\[].*?\b(remaster(ed)?|live|remix|acoustic|instrumental)\b.*?[\)\]]"#,
            #"\s+-\s+.*\b(remaster(ed)?|live|remix|acoustic|instrumental)\b.*$"#
        ] {
            name = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return (normalize(name), versions.subtracting(["remaster"]))
    }

    private static func artistKeys(_ artists: [String]) -> (primary: String, members: Set<String>, group: Set<String>) {
        let cleaned = artists.map {
            $0.replacingOccurrences(of: "薛之謙", with: "薛之谦")
                .replacingOccurrences(of: #"\b(feat\.?|ft\.?|featuring)\b"#, with: ",", options: [.regularExpression, .caseInsensitive])
        }
        let members = cleaned.flatMap {
            $0.components(separatedBy: CharacterSet(charactersIn: ",;×、"))
                .map(normalize)
                .filter { !$0.isEmpty }
        }
        let group = Set(cleaned.flatMap {
            $0.components(separatedBy: CharacterSet(charactersIn: ",&;×、"))
                .map(normalize)
                .filter { !$0.isEmpty }
        })
        return (members.first ?? "", Set(members), group)
    }

    private static func artistsMatch(source: Set<String>, candidate: Set<String>, primary: String) -> Bool {
        source == candidate || (candidate.isStrictSubset(of: source) && candidate.contains(primary))
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }
}
