import Foundation

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
        let request = request(for: track)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return try parse(data, for: track)
    }

    func parse(_ data: Data, for track: SpotifyTrack) throws -> [LyricLine] {
        let payload = try JSONDecoder().decode(Response.self, from: data)
        let candidate = TrackMatcher.Candidate(
            title: payload.track.title,
            artists: [payload.track.artist],
            durationMs: payload.track.duration * 1000
        )
        guard TrackMatcher.score(track, candidate: candidate) >= TrackMatcher.acceptanceThreshold,
              !hasLanguageConflict(payload, for: track) else { return [] }
        return payload.lines.map { LyricLine(time: Double($0.start) / 1000, text: $0.text) }
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
}
