import Foundation

struct LyricsClient {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        let primary = try? await lrclibLyrics(for: track)
        if let primary, !primary.isEmpty {
            return primary
        }
        return try await NetEaseLyricsSource().syncedLyrics(for: track)
    }

    private func lrclibLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.name),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("MenuBarLyrics/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 3

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "LyricsClient", code: 1)
        }

        let payload = try JSONDecoder().decode(LRCLIBGetResponse.self, from: data)
        guard let synced = payload.syncedLyrics, !synced.isEmpty else {
            return []
        }

        return LyricParser.parse(synced)
    }
}

private struct LRCLIBGetResponse: Decodable {
    let syncedLyrics: String?
}
