import Foundation

@MainActor
final class LyricsClient {
    typealias Source = @Sendable (SpotifyTrack) async throws -> [LyricLine]

    private var cache = LyricsCache(capacity: 100)
    private let sources: [Source]

    init(sources: [Source]? = nil) {
        self.sources = sources ?? [
            { try await Self.lrclibLyrics(for: $0) },
            { try await NetEaseLyricsSource().syncedLyrics(for: $0) },
            { try await LRCMuxLyricsSource().syncedLyrics(for: $0) }
        ]
    }

    func syncedLyrics(for track: SpotifyTrack, bypassCache: Bool = false) async throws -> [LyricLine] {
        let key = "\(track.name)\u{1F}\(track.artist)\u{1F}\(track.album)\u{1F}\(track.duration)"
        if let cached = cache.value(for: key, bypass: bypassCache) {
            return cached
        }

        let lines = await Self.firstNonEmpty(sources, for: track)
        cache.insert(lines, for: key)
        return lines
    }

    nonisolated static func firstNonEmpty(_ sources: [Source], for track: SpotifyTrack) async -> [LyricLine] {
        await withTaskGroup(of: [LyricLine]?.self) { group in
            for source in sources {
                group.addTask { try? await source(track) }
            }
            for await lines in group {
                if let lines, !lines.isEmpty {
                    group.cancelAll()
                    return lines
                }
            }
            return []
        }
    }

    nonisolated private static func lrclibLyrics(for track: SpotifyTrack) async throws -> [LyricLine] {
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

struct LyricsCache {
    private let capacity: Int
    private var values: [String: [LyricLine]] = [:]
    private var keys: [String] = []

    init(capacity: Int) {
        self.capacity = capacity
    }

    func value(for key: String, bypass: Bool = false) -> [LyricLine]? {
        bypass ? nil : values[key]
    }

    mutating func insert(_ lines: [LyricLine], for key: String) {
        guard !lines.isEmpty else { return }
        if values.updateValue(lines, forKey: key) == nil {
            keys.append(key)
        }
        if keys.count > capacity {
            values.removeValue(forKey: keys.removeFirst())
        }
    }
}

private struct LRCLIBGetResponse: Decodable {
    let syncedLyrics: String?
}
