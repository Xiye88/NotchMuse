import Foundation

struct SpotifyCanonicalIdentity: Decodable, Sendable {
    let nativeTrackID: String
    let title: String
    let artists: [String]
    let album: String
    let duration: Double
    let isrc: String?
    let identitySource: String

    enum CodingKeys: String, CodingKey {
        case nativeTrackID = "native_track_id", identitySource = "identity_source"
        case title, artists, album, duration, isrc
    }

    func validatedTrack(for player: SpotifyTrack, expectedURI: String) throws -> SpotifyTrack {
        let isPublic = identitySource == "Spotify public Embed URI response"
        guard expectedURI.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil,
              nativeTrackID == expectedURI, isPublic || identitySource == "official Spotify Get Track response",
              duration.isFinite, duration > 0, player.duration.isFinite, player.duration > 0,
              abs(duration - player.duration) <= 2, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isPublic || !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artists.isEmpty, artists.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              isrc == nil || RecordingISRC.normalized(isrc) != nil else { throw URLError(.cannotParseResponse) }
        if isPublic {
            guard isrc == nil, album.isEmpty, TrackMatcher.parsedTitle(title).name == TrackMatcher.parsedTitle(player.name).name,
                  TrackMatcher.parsedTitle(title).versions == TrackMatcher.parsedTitle(player.name).versions,
                  !player.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw URLError(.cannotParseResponse) }
            // The native dictionary exposes the primary artist, sometimes localized.
            // The exact URI binds the ordered public collaborators. Keep the native
            // primary name, album, version markers and duration; never infer ISRC.
            let nativeMembers = player.artist.components(separatedBy: CharacterSet(charactersIn: ",/&;×、")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let fullArtist = nativeMembers.count == 1 ? ([player.artist] + artists.dropFirst()).joined(separator: ", ") : player.artist
            return SpotifyTrack(name: player.name, artist: fullArtist, album: player.album, duration: player.duration, nativeTrackID: expectedURI)
        }
        // Native ID binds the official metadata. Keep actual player duration as
        // the timeline boundary; never copy this ISRC onto a lyric candidate.
        return SpotifyTrack(name: title, artist: artists.joined(separator: ", "), album: album, duration: player.duration)
    }
}

struct SpotifyIdentityResolver: Sendable {
    let endpoint: URL
    // Reuse transport connections; public requests still carry no account cookies.
    private static let publicSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    static func resolvePublic(_ uri: String) async throws -> SpotifyCanonicalIdentity {
        guard uri.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil else { throw URLError(.badURL) }
        let url = URL(string: "https://open.spotify.com/embed/track/" + uri.suffix(22))!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 5
        if let deadline = LyricsHTTP.deadline {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw URLError(.timedOut) }
            request.timeoutInterval = min(request.timeoutInterval, remaining)
        }
        try Task.checkCancellation()
        let (data, response) = try await publicSession.data(for: request)
        try Task.checkCancellation()
        guard data.count <= 2 * 1024 * 1024, response.url == url else { throw URLError(.badServerResponse) }
        return try parsePublicHTML(LyricsHTTP.validate(data: data, response: response), expectedURI: uri)
    }

    static func parsePublicHTML(_ data: Data, expectedURI: String) throws -> SpotifyCanonicalIdentity {
        guard expectedURI.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil,
              let html = String(data: data, encoding: .utf8) else { throw URLError(.cannotParseResponse) }
        let pattern = #"<script\b[^>]*\bid="__NEXT_DATA__"[^>]*>(.*?)</script>"#
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html),
              let json = String(html[range]).data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              let props = root["props"] as? [String: Any], let page = props["pageProps"] as? [String: Any],
              let state = page["state"] as? [String: Any], let payload = state["data"] as? [String: Any],
              let entity = payload["entity"] as? [String: Any], entity["type"] as? String == "track",
              entity["uri"] as? String == expectedURI, entity["id"] as? String == String(expectedURI.suffix(22)),
              let title = entity["name"] as? String, let duration = entity["duration"] as? Double,
              let entries = entity["artists"] as? [[String: Any]], !entries.isEmpty else { throw URLError(.cannotParseResponse) }
        let artists = try entries.map { artist -> String in
            guard let name = artist["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let uri = artist["uri"] as? String,
                  uri.range(of: #"^spotify:artist:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil else { throw URLError(.cannotParseResponse) }
            return name
        }
        // Only public display metadata is decoded. Ignore any unrelated page state;
        // no web token, cookie, private endpoint or lyric identity is extracted.
        return SpotifyCanonicalIdentity(nativeTrackID: expectedURI, title: title, artists: artists, album: "", duration: duration / 1000, isrc: nil, identitySource: "Spotify public Embed URI response")
    }

    func resolve(_ uri: String) async throws -> SpotifyCanonicalIdentity {
        guard uri.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil,
              endpoint.user == nil, endpoint.password == nil,
              endpoint.query == nil, endpoint.fragment == nil,
              endpoint.scheme == "https" || (endpoint.scheme == "http" && ["127.0.0.1", "localhost"].contains(endpoint.host)) else {
            throw URLError(.badURL)
        }
        let url = endpoint.appendingPathComponent("v1/spotify/track").appendingPathComponent(String(uri.suffix(22)))
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 8
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard data.count <= 1024 * 1024, response.url == url else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SpotifyCanonicalIdentity.self, from: LyricsHTTP.validate(data: data, response: response))
    }
}
