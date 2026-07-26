import Foundation

struct QQMusicLyricsSource {
    func syncedLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        try await withThrowingTaskGroup(of: [LyricLine].self) { group in
            group.addTask { try await fetchLyrics(for: track) }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next() ?? []
        }
    }

    private func fetchLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
        var lastError: Error?
        var songMID: String?
        for query in searchQueries(for: track) {
            do {
                if let match = try await search(query, for: track) {
                    songMID = match
                    break
                }
            } catch {
                lastError = error
            }
        }
        guard let songMID else {
            if let lastError { throw lastError }
            return []
        }

        let (data, response) = try await URLSession.shared.data(for: lyricRequest(songMID: songMID))
        return try parseLyrics(LyricsHTTP.validate(data: data, response: response))
    }

    func searchQueries(for track: SpotifyTrack) -> [String] {
        ["\(track.name) \(track.artist)", track.name]
    }

    func searchRequest(query: String) throws -> URLRequest {
        let body: [String: Any] = [
            "comm": ["ct": 19, "cv": "1859", "uin": "0"],
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "grp": 1,
                    "num_per_page": 20,
                    "page_num": 1,
                    "query": query,
                    "search_type": 0
                ]
            ]
        ]
        var request = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    func matchingSongMID(in data: Data, for track: SpotifyTrack) throws -> String? {
        let songs = try JSONDecoder().decode(SearchResponse.self, from: data).request.data.body.song.list
        let candidates = songs.map {
            TrackMatcher.Candidate(title: $0.title, artists: $0.singer.map(\.name), durationMs: $0.interval * 1000)
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: candidates, provider: "QQ") else { return nil }
        return songs[index].mid
    }

    func lyricRequest(songMID: String) -> URLRequest {
        var components = URLComponents(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")!
        components.queryItems = [
            URLQueryItem(name: "callback", value: "MusicJsonCallback_lrc"),
            URLQueryItem(name: "songmid", value: songMID),
            URLQueryItem(name: "g_tk", value: "5381"),
            URLQueryItem(name: "jsonpCallback", value: "MusicJsonCallback_lrc"),
            URLQueryItem(name: "loginUin", value: "0"),
            URLQueryItem(name: "hostUin", value: "0"),
            URLQueryItem(name: "format", value: "jsonp"),
            URLQueryItem(name: "inCharset", value: "utf8"),
            URLQueryItem(name: "outCharset", value: "utf8"),
            URLQueryItem(name: "notice", value: "0"),
            URLQueryItem(name: "platform", value: "yqq"),
            URLQueryItem(name: "needNewCode", value: "0")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    func smartboxRequest(query: String) -> URLRequest {
        var components = URLComponents(string: "https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg")!
        components.queryItems = [
            URLQueryItem(name: "key", value: query),
            URLQueryItem(name: "format", value: "json")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    func matchingSmartboxSongMID(in data: Data, for track: SpotifyTrack) throws -> String? {
        let songs = try JSONDecoder().decode(SmartboxResponse.self, from: data).data.song.itemlist
        let candidates = songs.map {
            TrackMatcher.Candidate(
                title: $0.name,
                artists: $0.singer.split(separator: "/").map(String.init),
                durationMs: Int(track.duration * 1000)
            )
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: candidates, provider: "QQ") else { return nil }
        return songs[index].mid
    }

    func songDetailsRequest(songMID: String) -> URLRequest {
        let callback = "getOneSongInfoCallback"
        var components = URLComponents(string: "https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg")!
        components.queryItems = [
            URLQueryItem(name: "songmid", value: songMID),
            URLQueryItem(name: "tpl", value: "yqq_song_detail"),
            URLQueryItem(name: "format", value: "jsonp"),
            URLQueryItem(name: "callback", value: callback),
            URLQueryItem(name: "g_tk", value: "5381"),
            URLQueryItem(name: "jsonpCallback", value: callback),
            URLQueryItem(name: "loginUin", value: "0"),
            URLQueryItem(name: "hostUin", value: "0"),
            URLQueryItem(name: "outCharset", value: "utf8"),
            URLQueryItem(name: "notice", value: "0"),
            URLQueryItem(name: "platform", value: "yqq"),
            URLQueryItem(name: "needNewCode", value: "0")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("NotchMuse/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        return request
    }

    func validatedSongMID(in data: Data, for track: SpotifyTrack) throws -> String? {
        let callback = "getOneSongInfoCallback"
        let response = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard response.hasPrefix("\(callback)("), let close = response.lastIndex(of: ")") else { return nil }
        let start = response.index(response.startIndex, offsetBy: callback.count + 1)
        let songs = try JSONDecoder().decode(SongDetailsResponse.self, from: Data(response[start..<close].utf8)).data
        let candidates = songs.map {
            TrackMatcher.Candidate(title: $0.title, artists: $0.singer.map(\.name), durationMs: $0.interval * 1000)
        }
        guard let index = TrackMatcher.bestMatchIndex(for: track, candidates: candidates, provider: "QQ") else { return nil }
        return songs[index].mid
    }

    func parseLyrics(_ data: Data) throws -> [LyricLine] {
        let callback = "MusicJsonCallback_lrc"
        let response = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard response.hasPrefix("\(callback)("),
              let close = response.lastIndex(of: ")") else { return [] }
        let start = response.index(response.startIndex, offsetBy: callback.count + 1)
        let payload = try JSONDecoder().decode(LyricResponse.self, from: Data(response[start..<close].utf8))
        guard payload.code == 0,
              let decoded = Data(base64Encoded: payload.lyric),
              let lrc = String(data: decoded, encoding: .utf8) else { return [] }
        return LyricParser.parse(lrc)
    }

    private func search(_ query: String, for track: SpotifyTrack) async throws -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(for: searchRequest(query: query))
            if let songMID = try matchingSongMID(in: LyricsHTTP.validate(data: data, response: response), for: track) {
                return songMID
            }
        } catch {
            // Fall through to Smartbox when the primary QQ endpoint fails.
        }
        return try await searchSmartbox(query, for: track)
    }

    private func searchSmartbox(_ query: String, for track: SpotifyTrack) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(for: smartboxRequest(query: query))
        guard let songMID = try matchingSmartboxSongMID(in: LyricsHTTP.validate(data: data, response: response), for: track) else { return nil }

        let (details, detailsResponse) = try await URLSession.shared.data(for: songDetailsRequest(songMID: songMID))
        return try validatedSongMID(in: LyricsHTTP.validate(data: details, response: detailsResponse), for: track)
    }
}

private struct SearchResponse: Decodable {
    let request: SearchRequest

    private enum CodingKeys: String, CodingKey {
        case request = "req_1"
    }
}

private struct SearchRequest: Decodable {
    let data: SearchData
}

private struct SearchData: Decodable {
    let body: SearchBody
}

private struct SearchBody: Decodable {
    let song: SearchSongs
}

private struct SearchSongs: Decodable {
    let list: [QQSong]
}

private struct QQSong: Decodable {
    let mid: String
    let title: String
    let singer: [QQSinger]
    let interval: Int
}

private struct QQSinger: Decodable {
    let name: String
}

private struct LyricResponse: Decodable {
    let code: Int
    let lyric: String
}

private struct SmartboxResponse: Decodable {
    let data: SmartboxData
}

private struct SmartboxData: Decodable {
    let song: SmartboxSongs
}

private struct SmartboxSongs: Decodable {
    let itemlist: [SmartboxSong]
}

private struct SmartboxSong: Decodable {
    let mid: String
    let name: String
    let singer: String
}

private struct SongDetailsResponse: Decodable {
    let data: [SongDetailsSong]
}

private struct SongDetailsSong: Decodable {
    let mid: String
    let title: String
    let singer: [QQSinger]
    let interval: Int
}
