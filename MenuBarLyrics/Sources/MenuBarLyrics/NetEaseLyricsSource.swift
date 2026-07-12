import Foundation

struct NetEaseLyricsSource {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        guard let song = try await search(track).first(where: {
            Self.matches(track, title: $0.name, artists: $0.artists.map(\.name), durationMs: $0.duration)
        }) else { return [] }

        var components = URLComponents(string: "https://music.163.com/api/song/lyric")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(song.id)),
            URLQueryItem(name: "lv", value: "-1")
        ]
        let (data, response) = try await URLSession.shared.data(for: request(components.url!))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let lyric = try JSONDecoder().decode(LyricResponse.self, from: data).lrc?.lyric ?? ""
        return LyricParser.parse(lyric)
    }

    static func matches(_ track: SpotifyTrack, title: String, artists: [String], durationMs: Int) -> Bool {
        let trackTitle = normalize(track.name)
        let candidateTitle = normalize(title)
        let titleMatches = trackTitle == candidateTitle || trackTitle.contains(candidateTitle) || candidateTitle.contains(trackTitle)
        let trackArtist = normalize(track.artist)
        let artistMatches = artists.map(normalize).contains { trackArtist.contains($0) || $0.contains(trackArtist) }
        return titleMatches && artistMatches && abs(track.duration - Double(durationMs) / 1000) <= 12
    }

    private func search(_ track: SpotifyTrack) async throws -> [Song] {
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "s", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0")
        ]
        var searchRequest = request(URL(string: "https://music.163.com/api/search/get/web")!)
        searchRequest.httpMethod = "POST"
        searchRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        searchRequest.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: searchRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return try JSONDecoder().decode(SearchResponse.self, from: data).result?.songs ?? []
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("MenuBarLyrics/0.2 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }
}

private struct SearchResponse: Decodable {
    let result: SearchResult?
}

private struct SearchResult: Decodable {
    let songs: [Song]
}

private struct Song: Decodable {
    let id: Int
    let name: String
    let artists: [Artist]
    let duration: Int
}

private struct Artist: Decodable {
    let name: String
}

private struct LyricResponse: Decodable {
    let lrc: LRC?
}

private struct LRC: Decodable {
    let lyric: String?
}
