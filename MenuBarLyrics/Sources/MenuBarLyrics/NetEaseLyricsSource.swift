import Foundation

struct NetEaseLyricsSource {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        let songs = try await search(track)
        let candidates = songs.map {
            TrackMatcher.Candidate(title: $0.name, artists: $0.artists.map(\.name), durationMs: $0.duration)
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: candidates, provider: "NetEase") else { return [] }
        let song = songs[index]

        var components = URLComponents(string: "https://music.163.com/api/song/lyric")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(song.id)),
            URLQueryItem(name: "lv", value: "-1")
        ]
        let (data, response) = try await URLSession.shared.data(for: request(components.url!))
        let lyric = try JSONDecoder().decode(LyricResponse.self, from: LyricsHTTP.validate(data: data, response: response)).lrc?.lyric ?? ""
        return LyricParser.parse(lyric)
    }

    private func search(_ track: SpotifyTrack) async throws -> [Song] {
        let searchRequest = searchRequest(for: track)
        let (data, response) = try await URLSession.shared.data(for: searchRequest)
        return try parseSearch(LyricsHTTP.validate(data: data, response: response))
    }

    func parseSearch(_ data: Data) throws -> [Song] {
        let songs = try JSONDecoder().decode(SearchResponse.self, from: data).result?.songs ?? []
        var seen = Set<NetEaseMetadataKey>()
        return songs.filter { seen.insert(metadataKey(for: $0)).inserted }
    }

    func searchRequest(for track: SpotifyTrack) -> URLRequest {
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "s", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0")
        ]
        var searchRequest = request(URL(string: "https://music.163.com/api/search/get")!)
        searchRequest.httpMethod = "POST"
        searchRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        searchRequest.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        return searchRequest
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    private func metadataKey(for song: Song) -> NetEaseMetadataKey {
        NetEaseMetadataKey(
            title: normalize(song.name),
            artists: Set(song.artists.map { normalize($0.name) }),
            duration: (song.duration + 500) / 1000
        )
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
    }

}

private struct NetEaseMetadataKey: Hashable {
    let title: String
    let artists: Set<String>
    let duration: Int
}

private struct SearchResponse: Decodable {
    let result: SearchResult?
}

private struct SearchResult: Decodable {
    let songs: [Song]
}

struct Song: Decodable {
    let id: Int
    let name: String
    let artists: [Artist]
    let duration: Int
}

struct Artist: Decodable {
    let name: String
}

private struct LyricResponse: Decodable {
    let lrc: LRC?
}

private struct LRC: Decodable {
    let lyric: String?
}
