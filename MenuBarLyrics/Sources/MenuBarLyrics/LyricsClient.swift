import Foundation

@MainActor
final class LyricsClient {
    typealias Source = @Sendable (SpotifyTrack) async throws -> [LyricLine]

    private var cache = LyricsCache(capacity: 100)
    private let sources: [Source]

    init(sources: [Source]? = nil) {
        self.sources = sources ?? [
            { try await LRCLIBLyricsSource().syncedLyrics(for: $0) },
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
