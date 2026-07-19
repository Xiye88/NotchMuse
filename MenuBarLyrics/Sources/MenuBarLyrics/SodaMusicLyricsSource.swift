import Foundation

struct SodaMusicLyricsSource {
    private static let userAgent = "LunaPC/2.1.0(12292405)"
    private let deviceID: String
    private let installID: String

    init(
        deviceID: String = "738\(Int.random(in: 10_000_000...99_999_999))\(Int.random(in: 10_000_000...99_999_999))",
        installID: String = "739\(Int.random(in: 10_000_000...99_999_999))\(Int.random(in: 10_000_000...99_999_999))"
    ) {
        self.deviceID = deviceID
        self.installID = installID
    }

    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        let (searchData, searchResponse) = try await URLSession.shared.data(for: searchRequest(for: track))
        guard let trackID = try matchingTrackID(
            in: LyricsHTTP.validate(data: searchData, response: searchResponse),
            for: track
        ) else { return [] }

        let (detailData, detailResponse) = try await URLSession.shared.data(for: detailRequest(trackID: trackID))
        return try parseDetail(LyricsHTTP.validate(data: detailData, response: detailResponse), for: track)
    }

    func searchRequest(for track: SpotifyTrack) -> URLRequest {
        var components = URLComponents(string: "https://api.qishui.com/luna/pc/search/track")!
        components.queryItems = commonQueryItems + [
            URLQueryItem(name: "q", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "cursor", value: ""),
            URLQueryItem(name: "search_id", value: ""),
            URLQueryItem(name: "search_method", value: "input")
        ]
        return request(url: components.url!)
    }

    func detailRequest(trackID: String) -> URLRequest {
        var components = URLComponents(string: "https://api.qishui.com/luna/pc/track_v2")!
        components.queryItems = commonQueryItems
        var request = request(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "track_id", value: trackID),
            URLQueryItem(name: "media_type", value: "track"),
            URLQueryItem(name: "queue_type", value: "")
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        return request
    }

    func matchingTrackID(in data: Data, for track: SpotifyTrack) throws -> String? {
        let response = try JSONDecoder().decode(SodaSearchResponse.self, from: data)
        let tracks = response.resultGroups.flatMap(\.data).compactMap { item in
            item.meta.itemType == "track" ? item.entity.track : nil
        }
        let candidates = tracks.map {
            TrackMatcher.Candidate(title: $0.name, artists: $0.artists.map(\.name), durationMs: $0.duration)
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: candidates) else { return nil }
        return tracks[index].id
    }

    func parseDetail(_ data: Data, for track: SpotifyTrack) throws -> [LyricLine] {
        let response = try JSONDecoder().decode(SodaDetailResponse.self, from: data)
        let candidate = TrackMatcher.Candidate(
            title: response.track.name,
            artists: response.track.artists.map(\.name),
            durationMs: response.track.duration
        )
        guard TrackMatcher.bestMatchIndex(for: track, candidates: [candidate]) == 0,
              let lyric = response.lyric else { return [] }
        return lyric.type.lowercased() == "krc"
            ? KugouLyricsSource().parseKRC(lyric.content)
            : LyricParser.parse(lyric.content)
    }

    private var commonQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "aid", value: "386088"),
            URLQueryItem(name: "app_name", value: "luna_pc"),
            URLQueryItem(name: "device_id", value: deviceID),
            URLQueryItem(name: "install_id", value: installID),
            URLQueryItem(name: "did", value: deviceID),
            URLQueryItem(name: "iid", value: installID),
            URLQueryItem(name: "device_platform", value: "PC"),
            URLQueryItem(name: "device_type", value: "pc"),
            URLQueryItem(name: "version_code", value: "2.1.0"),
            URLQueryItem(name: "version_name", value: "2.1.0")
        ]
    }

    private func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://api.qishui.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 8
        return request
    }
}

private struct SodaSearchResponse: Decodable {
    let resultGroups: [Group]

    struct Group: Decodable { let data: [Item] }
    struct Item: Decodable {
        let meta: Meta
        let entity: Entity
    }
    struct Meta: Decodable {
        let itemType: String
        enum CodingKeys: String, CodingKey { case itemType = "item_type" }
    }
    struct Entity: Decodable { let track: SodaTrack? }

    enum CodingKeys: String, CodingKey { case resultGroups = "result_groups" }
}

private struct SodaDetailResponse: Decodable {
    let lyric: SodaLyric?
    let track: SodaTrack
}

private struct SodaTrack: Decodable {
    let id: String
    let name: String
    let duration: Int
    let artists: [SodaArtist]
}

private struct SodaArtist: Decodable { let name: String }
private struct SodaLyric: Decodable {
    let content: String
    let type: String
}
