import Foundation
import LyricsCore
import zlib

struct KugouLyricsSource {
    struct Song {
        let hash: String
        let title: String
        let artist: String
        let duration: Int
    }

    struct LyricDownloadCandidate {
        let id: String
        let accessKey: String
        let title: String
        let artist: String
        let durationMs: Int
    }

    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        try await candidate(for: track)?.document.normalizedLines ?? []
    }

    func candidate(for track: SpotifyTrack) async throws -> LyricsCandidate? {
        try await withThrowingTaskGroup(of: LyricsCandidate?.self) { group in
            group.addTask { try await fetchCandidate(for: track) }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    private func fetchCandidate(for track: SpotifyTrack) async throws -> LyricsCandidate? {
        let (songData, songResponse) = try await LyricsHTTP.data(for: songSearchRequest(for: track))
        guard let song = try matchingSong(in: LyricsHTTP.validate(data: songData, response: songResponse), for: track) else {
            return nil
        }

        let keyword = "\(song.title) \(song.artist)"
        let (candidateData, candidateResponse) = try await URLSession.shared.data(
            for: lyricsSearchRequest(keyword: keyword, duration: song.duration, hash: song.hash)
        )
        guard let candidate = try matchingLyrics(
            in: LyricsHTTP.validate(data: candidateData, response: candidateResponse),
            for: track
        ) else { return nil }

        let (downloadData, downloadResponse) = try await URLSession.shared.data(
            for: downloadRequest(id: candidate.id, accessKey: candidate.accessKey)
        )
        let payload = try JSONDecoder().decode(
            DownloadResponse.self,
            from: LyricsHTTP.validate(data: downloadData, response: downloadResponse)
        )
        guard payload.status == 200, let content = payload.content, !content.isEmpty else { return nil }
        let lines = parseKRC(try decryptKRC(content))
        return makeCandidate(song: song, lyrics: candidate, lines: lines, for: track)
    }

    func makeCandidate(song: Song, lyrics: LyricDownloadCandidate, lines: [LyricLine], for track: SpotifyTrack) -> LyricsCandidate? {
        guard !lines.isEmpty else { return nil }
        let match = TrackMatcher.Candidate(title: lyrics.title, artists: [lyrics.artist], durationMs: lyrics.durationMs)
        // Hash identifies the recording; the lyric download ID is not a player song ID.
        return LyricsCandidate(document: TimedLyricDocument(lines: lines, metadata: LyricsMetadata(provider: "Kugou", platformTrackID: song.hash)),
            provider: "Kugou", sourcePlatform: "kugou", sourceTrackID: song.hash,
            sourceTitle: lyrics.title, sourceArtist: lyrics.artist, sourceAlbum: nil,
            sourceDuration: Double(lyrics.durationMs) / 1000, sourceISRC: nil, matcherScore: TrackMatcher.score(track, candidate: match))
    }

    func songSearchRequest(for track: SpotifyTrack) -> URLRequest {
        var components = URLComponents(string: "http://mobilecdn.kugou.com/api/v3/search/song")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "keyword", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "20"),
            URLQueryItem(name: "showtype", value: "1")
        ]
        return request(url: components.url!)
    }

    func lyricsSearchRequest(keyword: String, duration: Int, hash: String) -> URLRequest {
        var components = URLComponents(string: "https://lyrics.kugou.com/search")!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "man", value: "yes"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "duration", value: String(duration * 1000)),
            URLQueryItem(name: "hash", value: hash)
        ]
        return request(url: components.url!)
    }

    func downloadRequest(id: String, accessKey: String) -> URLRequest {
        var components = URLComponents(string: "https://lyrics.kugou.com/download")!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "accesskey", value: accessKey),
            URLQueryItem(name: "fmt", value: "krc"),
            URLQueryItem(name: "charset", value: "utf8")
        ]
        return request(url: components.url!)
    }

    func matchingSong(in data: Data, for track: SpotifyTrack) throws -> Song? {
        let response = try JSONDecoder().decode(SongSearchResponse.self, from: data)
        guard response.status == 1 else { return nil }
        let songs = deduplicated(response.data.info.flatMap { [$0] + ($0.group ?? []) }.map {
            Song(hash: $0.hash, title: $0.title, artist: $0.artist, duration: $0.duration)
        }, signature: { signature(title: $0.title, artist: $0.artist, durationMs: $0.duration * 1000) })
        let candidates = songs.map {
            TrackMatcher.Candidate(title: $0.title, artists: [$0.artist], durationMs: $0.duration * 1000)
        }
        guard let index = closestAcceptedIndex(for: track, candidates: candidates) else { return nil }
        return songs[index]
    }

    func matchingLyrics(in data: Data, for track: SpotifyTrack) throws -> LyricDownloadCandidate? {
        let response = try JSONDecoder().decode(LyricsSearchResponse.self, from: data)
        guard response.status == 200 else { return nil }
        let candidates = deduplicated(response.candidates.map {
            LyricDownloadCandidate(id: $0.id, accessKey: $0.accessKey, title: $0.title, artist: $0.artist, durationMs: $0.durationMs)
        }, signature: { signature(title: $0.title, artist: $0.artist, durationMs: $0.durationMs) })
        let matches = candidates.map {
            TrackMatcher.Candidate(title: $0.title, artists: [$0.artist], durationMs: $0.durationMs)
        }
        guard let index = closestAcceptedIndex(for: track, candidates: matches) else { return nil }
        return candidates[index]
    }

    private func closestAcceptedIndex(for track: SpotifyTrack, candidates: [TrackMatcher.Candidate]) -> Int? {
        let ranked = candidates.enumerated().compactMap { index, candidate -> (Int, Double)? in
            guard TrackMatcher.score(track, candidate: candidate) >= TrackMatcher.acceptanceThreshold else { return nil }
            return (index, abs(track.duration - Double(candidate.durationMs) / 1000))
        }.sorted { $0.1 < $1.1 }
        guard let best = ranked.first else { return nil }
        guard ranked.count < 2 || best.1 < ranked[1].1 else { return nil }
        return best.0
    }

    func decryptKRC(_ encoded: String) throws -> String {
        guard let encrypted = Data(base64Encoded: encoded),
              encrypted.count > 4,
              encrypted.prefix(4) == Data("krc1".utf8) else { throw KugouError.invalidKRC }

        let key: [UInt8] = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69]
        let compressed = Data(encrypted.dropFirst(4).enumerated().map { $0.element ^ key[$0.offset % key.count] })
        var outputSize = max(compressed.count * 4, 4_096)
        let maximumSize = 4 * 1_024 * 1_024

        while outputSize <= maximumSize {
            var output = Data(count: outputSize)
            var decodedSize = uLongf(outputSize)
            let result = compressed.withUnsafeBytes { source in
                output.withUnsafeMutableBytes { destination in
                    uncompress(
                        destination.bindMemory(to: Bytef.self).baseAddress!,
                        &decodedSize,
                        source.bindMemory(to: Bytef.self).baseAddress!,
                        uLong(compressed.count)
                    )
                }
            }
            if result == Z_OK {
                output.count = Int(decodedSize)
                guard var text = String(data: output, encoding: .utf8) else { throw KugouError.invalidKRC }
                if text.first == "\u{FEFF}" { text.removeFirst() }
                return text
            }
            guard result == Z_BUF_ERROR else { throw KugouError.invalidKRC }
            outputSize *= 2
        }
        throw KugouError.invalidKRC
    }

    func parseKRC(_ krc: String) -> [LyricLine] {
        LyricParser.parseKRC(krc)
    }

    private func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    private func deduplicated<T>(_ values: [T], signature: (T) -> String) -> [T] {
        var seen = Set<String>()
        return values.filter { seen.insert(signature($0)).inserted }
    }

    private func signature(title: String, artist: String, durationMs: Int) -> String {
        func normalized(_ value: String) -> String {
            value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars.filter(CharacterSet.alphanumerics.contains)
            .map(String.init).joined()
        }
        return "\(normalized(title))\u{1F}\(normalized(artist))\u{1F}\((durationMs + 500) / 1000)"
    }

    private enum KugouError: Error {
        case invalidKRC
    }
}

private struct SongSearchResponse: Decodable {
    let status: Int
    let data: SongSearchData
}

private struct SongSearchData: Decodable {
    let info: [SongSearchItem]
}

private struct SongSearchItem: Decodable {
    let hash: String
    let title: String
    let artist: String
    let duration: Int
    let group: [SongSearchItem]?

    private enum CodingKeys: String, CodingKey {
        case hash, duration, group
        case title = "songname"
        case artist = "singername"
    }
}

private struct LyricsSearchResponse: Decodable {
    let status: Int
    let candidates: [LyricsSearchItem]
}

private struct LyricsSearchItem: Decodable {
    let id: String
    let accessKey: String
    let artist: String
    let title: String
    let durationMs: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case accessKey = "accesskey"
        case artist = "singer"
        case title = "song"
        case durationMs = "duration"
    }
}

private struct DownloadResponse: Decodable {
    let status: Int
    let content: String?
}
