import Foundation

struct LRCLIBLyricsSource {
    func request(for track: SpotifyTrack) -> URLRequest {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "track_name", value: track.name),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("MenuBarLyrics/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6
        return request
    }

    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        let (data, response) = try await URLSession.shared.data(for: request(for: track))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return try parse(data, for: track)
    }

    func parse(_ data: Data, for track: SpotifyTrack) throws -> [LyricLine] {
        let results = try JSONDecoder().decode([Result].self, from: data)
        let usable = results.filter { $0.syncedLyrics?.isEmpty == false }
        let matching = usable.map { ($0, TrackMatcher.score(track, candidate: $0.candidate)) }
            .filter { $0.1 >= TrackMatcher.acceptanceThreshold }
            .sorted { $0.1 > $1.1 }
        guard !hasUnmarkedScriptConflict(matching.map(\.0), track: track),
              let lyrics = matching.first?.0.syncedLyrics else { return [] }
        return LyricParser.parse(lyrics)
    }

    private func hasUnmarkedScriptConflict(_ results: [Result], track: SpotifyTrack) -> Bool {
        guard !hasVersionMarker(track.name), !hasVersionMarker(track.album) else { return false }
        let scripts = Set(results.compactMap { script(of: $0.syncedLyrics ?? "") })
        return scripts.contains(.kana) && scripts.contains(.hangul)
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

private struct Result: Decodable {
    let trackName: String
    let artistName: String
    let duration: Double
    let syncedLyrics: String?

    var candidate: TrackMatcher.Candidate {
        TrackMatcher.Candidate(title: trackName, artists: [artistName], durationMs: Int(duration * 1000))
    }
}
