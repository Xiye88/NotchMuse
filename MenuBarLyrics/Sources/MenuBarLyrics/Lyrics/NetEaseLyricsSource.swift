import Foundation
import LyricsCore

struct NetEaseLyricsSource {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        try await candidate(for: track)?.document.normalizedLines ?? []
    }

    func candidate(for track: SpotifyTrack) async throws -> LyricsCandidate? {
        let songs = try await search(track)
        guard let song = selectedSong(songs, for: track) else { return nil }
        let lines = try await lyricLines(songID: String(song.id))
        return makeCandidate(song: song, lines: lines, for: track)
    }

    func selectedSong(_ songs: [Song], for track: SpotifyTrack) -> Song? {
        // Apply the existing recording gate before ranking; another album must
        // not hide the requested release during metadata deduplication.
        let bound = songs.filter {
            LyricsSelection.albumMatches($0.album?.name, track: track) &&
            TrackMatcher.identityRejectReason(track, title: $0.name, artist: $0.artists.map(\.name).joined(separator: ", "), album: $0.album?.name) == nil &&
            abs(Double($0.duration) / 1000 - track.duration) <= 2
        }
        let songs = bound.isEmpty ? songs : bound
        let candidates = songs.map {
            TrackMatcher.Candidate(title: $0.name, artists: $0.artists.map(\.name), durationMs: $0.duration)
        }
        guard let index = matchingIndex(for: track, candidates: candidates) else { return nil }
        return songs[index]
    }

    func makeCandidate(song: Song, lines: [LyricLine], for track: SpotifyTrack) -> LyricsCandidate? {
        guard !lines.isEmpty else { return nil }
        let match = TrackMatcher.Candidate(title: song.name, artists: song.artists.map(\.name), durationMs: song.duration)
        return LyricsCandidate(document: TimedLyricDocument(lines: lines, metadata: LyricsMetadata(provider: "NetEase", platformTrackID: String(song.id))),
            provider: "NetEase", sourcePlatform: "netease", sourceTrackID: String(song.id),
            sourceTitle: song.name, sourceArtist: song.artists.map(\.name).joined(separator: ", "), sourceAlbum: song.album?.name,
            sourceDuration: Double(song.duration) / 1000, sourceISRC: nil, matcherScore: TrackMatcher.score(track, candidate: match))
    }

    /// A public richer endpoint; IDs still come from conservative search or live-authorized Exact-ID.
    func lyricLines(songID: String) async throws -> [LyricLine] {
        do {
            let (data, response) = try await LyricsHTTP.data(for: lyricRequest(songID: songID, rich: true))
            let validated = try LyricsHTTP.validate(data: data, response: response)
            if let lines = try parseLyrics(validated) { return lines }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Existing endpoint remains available if the richer public endpoint fails.
        }
        try Task.checkCancellation()
        let (data, response) = try await LyricsHTTP.data(for: lyricRequest(songID: songID, rich: false))
        return try parseLyrics(LyricsHTTP.validate(data: data, response: response)) ?? []
    }

    func lyricRequest(songID: String, rich: Bool) -> URLRequest {
        var components = URLComponents(string: rich ? "https://music.163.com/api/song/lyric/v1" : "https://music.163.com/api/song/lyric")!
        components.queryItems = [URLQueryItem(name: "id", value: songID), URLQueryItem(name: "lv", value: "-1")]
        if rich {
            components.queryItems! += ["kv", "tv", "rv", "yv", "ytv", "yrv"].map { URLQueryItem(name: $0, value: "-1") }
        }
        return request(components.url!)
    }

    /// nil denotes an unsupported response, while [] is a legitimate no-lyrics result.
    func parseLyrics(_ data: Data) throws -> [LyricLine]? {
        let payload = try JSONDecoder().decode(LyricResponse.self, from: data)
        guard payload.code == 200 else { return nil }
        if let yrc = payload.yrc?.lyric {
            let lines = LyricParser.parseYRC(yrc)
            if !lines.isEmpty && lines.allSatisfy({ !$0.segments.isEmpty }) { return lines }
        }
        guard let lyric = payload.lrc?.lyric else { return nil }
        return LyricParser.parse(lyric)
    }

    func matchingIndex(for track: SpotifyTrack, candidates: [TrackMatcher.Candidate]) -> Int? {
        let matchingTrack = SpotifyTrack(
            name: track.name,
            artist: track.artist.replacingOccurrences(of: "/", with: ","),
            album: track.album,
            duration: track.duration
        )
        if let index = TrackMatcher.bestMatchIndex(for: matchingTrack, candidates: candidates, provider: "NetEase") {
            return index
        }
        guard track.duration > 0, track.duration <= 65 else { return nil }
        let exactIdentityMatches = candidates.indices.filter { index in
            let candidate = candidates[index]
            let fullDurationTrack = SpotifyTrack(
                name: matchingTrack.name,
                artist: matchingTrack.artist,
                album: matchingTrack.album,
                duration: Double(candidate.durationMs) / 1000
            )
            return TrackMatcher.score(fullDurationTrack, candidate: candidate) >= TrackMatcher.acceptanceThreshold
        }
        return exactIdentityMatches.count == 1 ? exactIdentityMatches[0] : nil
    }

    private func search(_ track: SpotifyTrack) async throws -> [Song] {
        let searchRequest = searchRequest(for: track)
        let (data, response) = try await LyricsHTTP.data(for: searchRequest)
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
            album: song.album?.name.map(normalize),
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
    let album: String?
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
    let album: NetEaseAlbum?
}

struct NetEaseAlbum: Decodable { let name: String? }

struct Artist: Decodable {
    let name: String
}

private struct LyricResponse: Decodable {
    let code: Int?
    let yrc: LRC?
    let lrc: LRC?
}

private struct LRC: Decodable {
    let lyric: String?
}
