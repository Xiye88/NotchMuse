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

    static func identityRejectReason(_ track: SpotifyTrack, title: String, artist: String, album: String?) -> String? {
        let requested = parsedTitle(track.name), source = parsedTitle(title)
        if requested.name != source.name { return "title_mismatch" }
        if requested.versions != source.versions { return "version_mismatch" }
        let a = artistKeys([track.artist])
        let b = artistKeys([artist])
        let candidateGroup = artistGroupKey(artist, expectedArtists: [track.artist])
        if a.members != b.members && a.group != candidateGroup { return "artist_mismatch" }
        func versions(_ value: String) -> Set<String> {
            var result = parsedTitle(value).versions
            for hint in ["现场", "翻唱", "伴奏", "混音", "重录"] where value.contains(hint) { result.insert(hint) }
            return result
        }
        if let album, versions(track.name + " " + track.album) != versions(title + " " + album) { return "album_version_mismatch" }
        return nil
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
        let contextCandidateGroup = Set(candidate.artists.flatMap { artistGroupKey($0, expectedArtists: [track.artist]) })
        let artistsMatch = artistsMatch(source: sourceArtists.members, candidate: candidateArtists.members)
            || artistsMatch(source: sourceArtists.group, candidate: contextCandidateGroup)
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

    static func parsedTitle(_ title: String) -> (name: String, versions: Set<String>) {
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        var name = folded
        for pattern in [
            #"[\(\[].*?\b(feat\.?|ft\.?|featuring)\b.*?[\)\]]"#,
            #"\s+\b(feat\.?|ft\.?|featuring)\b.*$"#
        ] {
            name = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        var versions = Set(["live", "remix", "acoustic", "instrumental", "remaster", "remastered", "cover", "rerecorded"].filter {
            name.range(of: "\\b\($0)\\b", options: .regularExpression) != nil
        }.map { $0 == "remastered" ? "remaster" : $0 })
        if versions.contains("remaster") {
            let year = try! NSRegularExpression(pattern: #"\b(?:19|20)\d{2}\b"#)
            for match in year.matches(in: name, range: NSRange(name.startIndex..., in: name)) {
                if let range = Range(match.range, in: name) { versions.insert("remaster:" + name[range]) }
            }
        }
        for pattern in [
            #"[\(\[].*?\b(remaster(ed)?|live|remix|acoustic|instrumental)\b.*?[\)\]]"#,
            #"\s+-\s+.*\b(remaster(ed)?|live|remix|acoustic|instrumental)\b.*$"#
        ] {
            name = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return (normalize(name), versions)
    }

    /// Returns a candidate's grouped artist identity while treating a literal "and"
    /// as a separator only when every resulting part is already present in the
    /// expected track artist group. This keeps natural-language names intact and
    /// avoids global string replacement.
    static func artistGroupKey(_ artist: String, expectedArtists: [String]) -> Set<String> {
        let base = artistKeys([artist]).group
        let expected = artistKeys(expectedArtists).group
        guard expected.count >= 2 else { return base }

        let andSeparated = artist.replacingOccurrences(of: #"\s+\band\b\s+"#, with: ",", options: .regularExpression)
        let parts = andSeparated.components(separatedBy: ",")
            .map(normalize)
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return base }
        let split = Set(parts)
        guard split.isSubset(of: expected) else { return base }
        return base.subtracting([normalize(artist)]).union(split)
    }

    static func artistKeys(_ artists: [String]) -> (members: Set<String>, group: Set<String>) {
        let cleaned = artists.map {
            $0.replacingOccurrences(of: "薛之謙", with: "薛之谦")
                .replacingOccurrences(of: "JC 陈咏桐", with: "JC", options: .caseInsensitive)
                .replacingOccurrences(of: #"\b(feat\.?|ft\.?|featuring)\b"#, with: ",", options: [.regularExpression, .caseInsensitive])
        }
        let members = cleaned.flatMap {
            $0.components(separatedBy: CharacterSet(charactersIn: ",;/×、"))
                .map(normalize)
                .filter { !$0.isEmpty }
        }
        let group = Set(cleaned.flatMap {
            $0.components(separatedBy: CharacterSet(charactersIn: ",&;/×、"))
                .map(normalize)
                .filter { !$0.isEmpty }
        })
        return (Set(members), group)
    }

    private static func artistsMatch(source: Set<String>, candidate: Set<String>) -> Bool {
        source == candidate
    }

    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let simplified = folded.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? folded
        // Only reversible spelling equivalents: 髮/發 and 幹/乾 must not collapse.
        let canonical = simplified.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) == folded ? simplified : folded
        return canonical
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }
}
