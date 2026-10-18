import Foundation
import LyricsCore

struct LRCMuxLyricsSource {
    func request(for track: SpotifyTrack) -> URLRequest {
        var components = URLComponents(string: "https://api.lrcmux.dev/get")!
        components.queryItems = [
            URLQueryItem(name: "title", value: track.name),
            URLQueryItem(name: "artist", value: track.artist),
            URLQueryItem(name: "album", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded()))),
            URLQueryItem(name: "level", value: "line"),
            URLQueryItem(name: "strict", value: "true"),
            URLQueryItem(name: "format", value: "json")
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 5
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
        let payload = try JSONDecoder().decode(Response.self, from: data)
        let candidate = TrackMatcher.Candidate(
            title: payload.track.title,
            artists: [payload.track.artist],
            durationMs: payload.track.duration * 1000
        )
        guard TrackMatcher.score(track, candidate: candidate) >= TrackMatcher.acceptanceThreshold,
              !hasLanguageConflict(payload, for: track) else { return nil }
        let synthesizedEnd = payload.meta.level == "line" && ["lrclib", "netease", "musixmatch"].contains(payload.meta.source.id.lowercased())
        let lines = payload.lines.filter { !$0.text.isEmpty }.map { line in
            LyricLine(time: Double(line.start) / 1000, text: line.text, endTime: Double(line.end) / 1000,
                      segments: (line.words ?? []).map { LyricSegment(time: Double($0.start) / 1000, endTime: Double($0.end) / 1000, text: $0.text) },
                      endTimeIsEstimated: synthesizedEnd)
        }.sorted { $0.time < $1.time }
        guard !lines.isEmpty else { return nil }
        let platform = payload.meta.source.id.lowercased()
        let sourceID = sourceTrackID(url: payload.meta.source.url, platform: platform)
        // The track ISRC belongs to the resolver result. It alone does not prove
        // that a cross-platform lyric timeline is bound to that recording.
        return LyricsCandidate(document: TimedLyricDocument(lines: lines, metadata: LyricsMetadata(provider: "LRCMux", platformTrackID: sourceID, isrc: payload.track.isrc)),
            provider: "LRCMux", sourcePlatform: platform, sourceTrackID: sourceID,
            sourceTitle: payload.track.title, sourceArtist: payload.track.artist, sourceAlbum: payload.track.album,
            sourceDuration: Double(payload.track.duration), sourceISRC: payload.track.isrc,
            matcherScore: TrackMatcher.score(track, candidate: candidate))
    }

    private func sourceTrackID(url: String, platform: String) -> String? {
        guard let components = URLComponents(string: url), components.scheme == "https",
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased() else { return nil }
        let query = components.queryItems ?? []
        if platform == "netease", host == "music.163.com" || host == "y.music.163.com" {
            // NetEase public song links can put the song query inside a URL fragment.
            let fragment = components.fragment.flatMap { URLComponents(string: $0)?.queryItems } ?? []
            return (query + fragment).first { $0.name == "id" }?.value.flatMap { value in
                value.allSatisfy(\.isNumber) && !value.isEmpty ? value : nil
            }
        }
        if platform == "spotify", host == "open.spotify.com", components.path.hasPrefix("/track/") {
            let value = components.path.split(separator: "/").last.map(String.init)
            return value.flatMap { $0.count == 22 && $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) } ? $0 : nil }
        }
        if platform == "lrclib", host == "lrclib.net", components.path.hasPrefix("/api/get/") {
            return components.path.split(separator: "/").last.map(String.init)
        }
        return nil
    }

    private func hasLanguageConflict(_ payload: Response, for track: SpotifyTrack) -> Bool {
        guard payload.track.isrc?.hasPrefix("KR") == true,
              !isMarkedJapanese(track.name), !isMarkedJapanese(track.album) else { return false }
        let scalars = payload.lines.flatMap(\.text.unicodeScalars)
        let kana = scalars.count { (0x3040...0x30FF).contains($0.value) || (0xFF66...0xFF9D).contains($0.value) }
        let hangul = scalars.count { (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value) || (0xAC00...0xD7AF).contains($0.value) }
        return kana >= 4 && hangul * 10 < kana
    }

    private func isMarkedJapanese(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.contains("jp") || words.contains("japanese")
    }
}

private struct Response: Decodable {
    let track: Track
    let meta: Meta
    let lines: [Line]
}

private struct Track: Decodable {
    let isrc: String?
    let title: String
    let artist: String
    let album: String
    let duration: Int
}

private struct Meta: Decodable {
    let source: Source
    let level: String
}

private struct Source: Decodable {
    let id: String
    let name: String
    let url: String
}

private struct Line: Decodable {
    let text: String
    let start: Int
    let end: Int
    let words: [Word]?
}

private struct Word: Decodable {
    let text: String
    let start: Int
    let end: Int
}
