import Foundation

struct LRCMuxLyricsSource {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://api.lrcmux.dev/get")!
        components.queryItems = [
            URLQueryItem(name: "title", value: track.name),
            URLQueryItem(name: "artist", value: track.artist),
            URLQueryItem(name: "level", value: "line"),
            URLQueryItem(name: "strict", value: "true"),
            URLQueryItem(name: "format", value: "lrc")
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 5
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return LyricParser.parse(String(decoding: data, as: UTF8.self))
    }
}
