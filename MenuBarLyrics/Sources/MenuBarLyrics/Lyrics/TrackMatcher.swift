import Foundation

enum TrackMatcher {
    static let acceptanceThreshold = 82

    struct Candidate {
        let title: String
        let artists: [String]
        let durationMs: Int
    }

    struct CandidateDiagnostics {
        let index: Int
        let score: Int
        let rejectReason: String
    }

    struct Diagnostics {
        let selectedIndex: Int?
        let rejectReason: String
        let topScore: Int
        let secondScore: Int
        let ambiguityGap: Int
        let candidates: [CandidateDiagnostics]
    }

    static func score(_ track: SpotifyTrack, candidate: Candidate) -> Int {
        let sourceTitle = parsedTitle(track.name)
        let candidateTitle = parsedTitle(candidate.title)
        let durationDifference = abs(track.duration - Double(candidate.durationMs) / 1000)

        guard sourceTitle.name == candidateTitle.name,
              sourceTitle.versions == candidateTitle.versions,
              durationDifference <= 8 else { return 0 }

        let sourceArtists = artistKeys([track.artist])
        let candidateArtists = artistKeys(candidate.artists)
        let artistsMatch = artistsMatch(source: sourceArtists.members, candidate: candidateArtists.members)
            || artistsMatch(source: sourceArtists.group, candidate: candidateArtists.group)
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

    static func bestMatchIndex(for track: SpotifyTrack, candidates: [Candidate], provider: String = "unknown") -> Int? {
        let result = diagnostics(for: track, candidates: candidates)
        DebugLog.lyricsDiagnostic(
            "matcher.ranking provider=\(provider) candidates=\(candidates.count) top=\(result.topScore) second=\(result.secondScore) gap=\(result.ambiguityGap) selected=\(result.selectedIndex.map(String.init) ?? "none") reason=\(result.rejectReason)"
        )
        for ranked in result.candidates.prefix(3) {
            let candidate = candidates[ranked.index]
            let artist = candidate.artists.joined(separator: "/")
            DebugLog.lyricsDiagnostic(
                "matcher.candidate provider=\(provider) rank=\(ranked.index) title=\(DebugLog.metadata(candidate.title)) artist=\(DebugLog.metadata(artist)) duration=\(candidate.durationMs / 1000) score=\(ranked.score) reason=\(ranked.rejectReason)"
            )
        }
        return result.selectedIndex
    }

    static func diagnostics(for track: SpotifyTrack, candidates: [Candidate]) -> Diagnostics {
        let ranked = candidates.enumerated()
            .map { (index: $0.offset, score: score(track, candidate: $0.element)) }
            .sorted { $0.score > $1.score }
        let topScore = ranked.first?.score ?? 0
        let secondScore = ranked.dropFirst().first?.score ?? 0
        let gap = ranked.count >= 2 ? topScore - secondScore : topScore
        let selectedIndex: Int?
        let reason: String
        if ranked.isEmpty {
            selectedIndex = nil
            reason = "no_candidates"
        } else if topScore < acceptanceThreshold {
            selectedIndex = nil
            reason = "below_threshold"
        } else if ranked.count >= 2 && gap < 6 {
            selectedIndex = nil
            reason = "ambiguous_gap"
        } else {
            selectedIndex = ranked[0].index
            reason = "selected"
        }
        let selected = selectedIndex
        return Diagnostics(
            selectedIndex: selectedIndex,
            rejectReason: reason,
            topScore: topScore,
            secondScore: secondScore,
            ambiguityGap: gap,
            candidates: ranked.map { item in
                CandidateDiagnostics(
                    index: item.index,
                    score: item.score,
                    rejectReason: item.index == selected ? "selected" : rejectReason(track, candidate: candidates[item.index], score: item.score)
                )
            }
        )
    }

    private static func rejectReason(_ track: SpotifyTrack, candidate: Candidate, score: Int) -> String {
        let sourceTitle = parsedTitle(track.name)
        let candidateTitle = parsedTitle(candidate.title)
        let durationDifference = abs(track.duration - Double(candidate.durationMs) / 1000)
        if sourceTitle.name != candidateTitle.name { return "title_mismatch" }
        if sourceTitle.versions != candidateTitle.versions { return "version_mismatch" }
        if durationDifference > 8 { return "duration_over_8s" }
        let sourceArtists = artistKeys([track.artist])
        let candidateArtists = artistKeys(candidate.artists)
        let artistsMatch = artistsMatch(source: sourceArtists.members, candidate: candidateArtists.members)
            || artistsMatch(source: sourceArtists.group, candidate: candidateArtists.group)
        if !artistsMatch { return "artist_mismatch" }
        return score < acceptanceThreshold ? "below_threshold" : "ambiguous_shadow"
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

    private static func artistKeys(_ artists: [String]) -> (members: Set<String>, group: Set<String>) {
        let cleaned = artists.map {
            $0.replacingOccurrences(of: "薛之謙", with: "薛之谦")
                .replacingOccurrences(of: "JC 陈咏桐", with: "JC", options: .caseInsensitive)
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
        return (Set(members), group)
    }

    private static func artistsMatch(source: Set<String>, candidate: Set<String>) -> Bool {
        source == candidate
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }
}
