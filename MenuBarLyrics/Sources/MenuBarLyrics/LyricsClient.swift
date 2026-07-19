import Foundation

enum LyricsClientError: Error, Equatable {
    case networkFailure
}

@MainActor
final class LyricsClient {
    typealias Source = @Sendable (SpotifyTrack) async throws -> [LyricLine]

    private var cache = LyricsCache(capacity: 100)
    private let sources: [Source]

    init(sources: [Source]? = nil) {
        self.sources = sources ?? [
            { try await LRCLIBLyricsSource().syncedLyrics(for: $0) },
            { try await NetEaseLyricsSource().syncedLyrics(for: $0) },
            { try await LRCMuxLyricsSource().syncedLyrics(for: $0) },
            { try await QQMusicLyricsSource().syncedLyrics(for: $0) },
            { try await KugouLyricsSource().syncedLyrics(for: $0) },
            { try await SodaMusicLyricsSource().syncedLyrics(for: $0) }
        ]
    }

    func syncedLyrics(for track: SpotifyTrack, bypassCache: Bool = false) async throws -> [LyricLine] {
        let key = "\(track.name)\u{1F}\(track.artist)\u{1F}\(track.album)\u{1F}\(track.duration)"
        if let cached = cache.value(for: key, bypass: bypassCache) {
            return cached
        }

        let result = await Self.firstNonEmptyResult(sources, for: track)
        guard result.hadSuccessfulSource else {
            DebugLog.lyrics("Lyrics search failed for \(track.name): all sources failed")
            throw LyricsClientError.networkFailure
        }
        let lines = result.lines
        if lines.isEmpty {
            DebugLog.lyrics("Lyrics search found no match for \(track.name) by \(track.artist)")
        }
        cache.insert(lines, for: key)
        return lines
    }

    nonisolated static func firstNonEmpty(_ sources: [Source], for track: SpotifyTrack) async -> [LyricLine] {
        await firstNonEmptyResult(sources, for: track).lines
    }

    nonisolated private static func firstNonEmptyResult(
        _ sources: [Source],
        for track: SpotifyTrack
    ) async -> (lines: [LyricLine], hadSuccessfulSource: Bool) {
        await withTaskGroup(of: (lines: [LyricLine]?, succeeded: Bool).self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    do {
                        return (try await source(track), true)
                    } catch let error as DecodingError {
                        DebugLog.lyrics("Lyrics source \(index + 1) parsing failed: \(error.localizedDescription)")
                        return (nil, false)
                    } catch let error as URLError {
                        DebugLog.lyrics("Lyrics source \(index + 1) network failed: \(error.localizedDescription)")
                        return (nil, false)
                    } catch {
                        DebugLog.lyrics("Lyrics source \(index + 1) search failed: \(error.localizedDescription)")
                        return (nil, false)
                    }
                }
            }
            var hadSuccessfulSource = false
            for await result in group {
                hadSuccessfulSource = hadSuccessfulSource || result.succeeded
                if let lines = result.lines, !lines.isEmpty {
                    group.cancelAll()
                    return (lines, true)
                }
            }
            return ([], hadSuccessfulSource)
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
