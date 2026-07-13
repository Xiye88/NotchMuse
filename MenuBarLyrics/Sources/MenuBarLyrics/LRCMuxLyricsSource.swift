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
            URLQueryItem(name: "format", value: "lrc")
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 5
        return request
    }

    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        let request = request(for: track)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return LyricParser.parse(String(decoding: data, as: UTF8.self))
    }
}
