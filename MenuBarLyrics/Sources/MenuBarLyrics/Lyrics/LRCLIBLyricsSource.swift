import Foundation
import LyricsCore

struct LRCLIBLyricsSource {
    func request(for track: SpotifyTrack) -> URLRequest {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.name),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        try await candidate(for: track)?.document.normalizedLines ?? []
    }

    func candidate(for track: SpotifyTrack) async throws -> LyricsCandidate? {
        let (data, response) = try await LyricsHTTP.data(for: request(for: track))
        return try parseCandidate(LyricsHTTP.validate(data: data, response: response), for: track)
    }

    func parse(_ data: Data, for track: SpotifyTrack) throws -> [LyricLine] {
        try parseCandidate(data, for: track)?.document.normalizedLines ?? []
    }

    func parseCandidate(_ data: Data, for track: SpotifyTrack) throws -> LyricsCandidate? {
        let results = try JSONDecoder().decode([Result].self, from: data)
        let available = results.filter { $0.syncedLyrics?.isEmpty == false && $0.duration != nil }
        guard !hasUnmarkedScriptConflict(available, track: track),
              !hasDuplicateScriptConflict(available, track: track) else { return nil }
        let bound = available.filter {
            LyricsSelection.albumMatches($0.albumName, track: track) &&
            TrackMatcher.identityRejectReason(track, title: $0.trackName, artist: $0.artistName, album: $0.albumName) == nil &&
            abs(($0.duration ?? 0) - track.duration) <= 2
        }
        let usable = bound.isEmpty ? available : bound

        // Search uploads can share title/artist yet describe different recordings.
        // Reject competing payloads before metadata dedup can hide the disagreement.
        let topScore = usable.map { TrackMatcher.score(track, candidate: $0.candidate) }.max() ?? 0
        let contenders = usable.filter {
            let score = TrackMatcher.score(track, candidate: $0.candidate)
            return score >= TrackMatcher.acceptanceThreshold && topScore - score < 6
        }
        func candidate(_ row: Result) -> LyricsCandidate {
            LyricsCandidate(document: LyricParser.parseDocument(row.syncedLyrics ?? "", provider: "LRCLIB"),
                provider: "LRCLIB", sourcePlatform: "lrclib", sourceTrackID: row.id.map(String.init),
                sourceTitle: row.trackName, sourceArtist: row.artistName, sourceAlbum: row.albumName,
                sourceDuration: row.duration, matcherScore: TrackMatcher.score(track, candidate: row.candidate))
        }
        for group in Dictionary(grouping: contenders, by: { metadataKey(for: $0, track: track) }).values {
            for i in group.indices {
                for j in group.indices where j > i {
                    let a = candidate(group[i]), b = candidate(group[j])
                    let identical = a.document.normalizedLines == b.document.normalizedLines && abs((a.sourceDuration ?? 0) - (b.sourceDuration ?? 0)) <= 1
                    let comparable = a.document.lines.count >= 5 && b.document.lines.count >= 5 &&
                        abs((a.sourceDuration ?? 0) - track.duration) <= 2 && abs((b.sourceDuration ?? 0) - track.duration) <= 2 &&
                        LyricsSelection.timelinesAgree(a, b)
                    if !identical && !comparable {
                        DebugLog.lyricsDiagnostic("matcher.provider_internal_conflict provider=LRCLIB reason=recording_ambiguity")
                        return nil
                    }
                }
            }
        }

        var indices = [MetadataKey: Int]()
        var unique = [Result]()
        for result in usable {
            let key = metadataKey(for: result, track: track)
            if let index = indices[key] {
                if TrackMatcher.score(track, candidate: result.candidate) > TrackMatcher.score(track, candidate: unique[index].candidate) {
                    unique[index] = result
                }
            } else {
                indices[key] = unique.count
                unique.append(result)
            }
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: unique.map(\.candidate), provider: "LRCLIB"),
              let lyrics = unique[index].syncedLyrics,
              !hasSuspiciousKana(lyrics, for: track) else { return nil }
        let selected = unique[index]
        return LyricsCandidate(document: LyricParser.parseDocument(lyrics, provider: "LRCLIB"),
            provider: "LRCLIB", sourcePlatform: "lrclib", sourceTrackID: selected.id.map(String.init),
            sourceTitle: selected.trackName, sourceArtist: selected.artistName, sourceAlbum: selected.albumName,
            sourceDuration: selected.duration, sourceISRC: nil, matcherScore: TrackMatcher.score(track, candidate: selected.candidate))
    }

    private func hasUnmarkedScriptConflict(_ results: [Result], track: SpotifyTrack) -> Bool {
        guard ![track.name, track.artist, track.album].contains(where: hasVersionMarker) else { return false }
        let scripts = Set(results.compactMap { script(of: $0.syncedLyrics ?? "") })
        return scripts.contains(.kana) && scripts.contains(.hangul)
    }

    private func hasDuplicateScriptConflict(_ results: [Result], track: SpotifyTrack) -> Bool {
        Dictionary(grouping: results, by: { metadataKey(for: $0, track: track) }).values.contains {
            let scripts = Set($0.compactMap { script(of: $0.syncedLyrics ?? "") })
            return scripts.contains(.kana) && scripts.contains(.hangul)
        }
    }

    private func metadataKey(for result: Result, track: SpotifyTrack) -> MetadataKey {
        MetadataKey(
            title: normalize(result.trackName),
            artist: TrackMatcher.artistGroupKey(result.artistName, expectedArtists: [track.artist])
        )
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }

    private func hasSuspiciousKana(_ lyrics: String, for track: SpotifyTrack) -> Bool {
        let metadata = [track.name, track.artist, track.album]
        return metadata.allSatisfy(isLatin)
            && !metadata.contains(where: isMarkedJapanese)
            && script(of: lyrics) == .kana
    }

    private func isLatin(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            !CharacterSet.letters.contains($0) || isLatinLetter($0.value)
        }
    }

    private func isLatinLetter(_ value: UInt32) -> Bool {
        (0x0041...0x007A).contains(value)
            || (0x00C0...0x024F).contains(value)
            || (0x1E00...0x1EFF).contains(value)
            || (0xFF21...0xFF5A).contains(value)
    }

    private func isMarkedJapanese(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.contains("jp") || words.contains("japanese")
    }

    private func hasVersionMarker(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.contains { ["jp", "japanese", "kr", "korean"].contains($0) }
    }

    private func script(of text: String) -> Script? {
        let values = text.unicodeScalars.map(\.value)
        let kana = values.count { (0x3040...0x30FF).contains($0) || (0xFF66...0xFF9D).contains($0) }
        let hangul = values.count { (0x1100...0x11FF).contains($0) || (0x3130...0x318F).contains($0) || (0xAC00...0xD7AF).contains($0) }
        if kana >= 4 && kana > hangul * 10 { return .kana }
        if hangul >= 4 && hangul > kana * 10 { return .hangul }
        return nil
    }
}

private enum Script {
    case kana, hangul
}

private struct MetadataKey: Hashable {
    let title: String
    let artist: Set<String>
}

private struct Result: Decodable {
    let id: Int?
    let albumName: String?
    let trackName: String
    let artistName: String
    let duration: Double?
    let syncedLyrics: String?

    var candidate: TrackMatcher.Candidate {
        TrackMatcher.Candidate(title: trackName, artists: [artistName], durationMs: Int((duration ?? 0) * 1000))
    }
}
