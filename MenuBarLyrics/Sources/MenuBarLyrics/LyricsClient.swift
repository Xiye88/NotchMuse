import Foundation

enum LyricsClientError: Error, Equatable {
    case networkFailure
}

@MainActor
final class LyricsClient {
    typealias Source = @Sendable (SpotifyTrack) async throws -> [LyricLine]

    private var cache = LyricsCache(capacity: 100)
    private let sources: [Source]
    private let sourceNames: [String]
    private(set) var selectedProvider: String?

    init(sources: [Source]? = nil) {
        if let sources {
            self.sources = sources
            self.sourceNames = sources.indices.map { "source_\($0 + 1)" }
            return
        }
        self.sources = [
            { try await LRCLIBLyricsSource().syncedLyrics(for: $0) },
            { try await NetEaseLyricsSource().syncedLyrics(for: $0) },
            { try await LRCMuxLyricsSource().syncedLyrics(for: $0) },
            { try await QQMusicLyricsSource().syncedLyrics(for: $0) },
            { try await KugouLyricsSource().syncedLyrics(for: $0) },
            { try await SodaMusicLyricsSource().syncedLyrics(for: $0) }
        ]
        self.sourceNames = ["LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"]
    }

    func syncedLyrics(for track: SpotifyTrack, bypassCache: Bool = false) async throws -> [LyricLine] {
        let key = "\(track.name)\u{1F}\(track.artist)\u{1F}\(track.album)\u{1F}\(track.duration)"
        if let cached = cache.value(for: key, bypass: bypassCache) {
            selectedProvider = nil
            return cached
        }

        selectedProvider = nil
        DebugLog.lyricsDiagnostic("matcher.track title=\(DebugLog.metadata(track.name)) artist=\(DebugLog.metadata(track.artist)) album=\(DebugLog.metadata(track.album)) duration=\(Int(track.duration.rounded()))")
        let result = await Self.firstNonEmptyResult(sources, names: sourceNames, for: track)
        guard result.hadSuccessfulSource else {
            DebugLog.lyrics("Lyrics search failed for \(track.name): all sources failed")
            throw LyricsClientError.networkFailure
        }
        let lines = result.lines
        selectedProvider = result.selectedProvider
        if lines.isEmpty {
            DebugLog.lyrics("Lyrics search found no match for \(track.name) by \(track.artist)")
        }
        cache.insert(lines, for: key)
        return lines
    }

    nonisolated static func firstNonEmpty(_ sources: [Source], for track: SpotifyTrack) async -> [LyricLine] {
        await firstNonEmptyResult(sources, for: track).lines
    }

    struct SourceAggregate {
        let lines: [LyricLine]
        let hadSuccessfulSource: Bool
        let aggregateReason: String
        let selectedProvider: String?
    }

    nonisolated static func firstNonEmptyResult(
        _ sources: [Source],
        names: [String]? = nil,
        for track: SpotifyTrack
    ) async -> SourceAggregate {
        await withTaskGroup(of: (name: String, lines: [LyricLine]?, succeeded: Bool).self) { group in
            for (index, source) in sources.enumerated() {
                let name = names?[safe: index] ?? "source_\(index + 1)"
                group.addTask {
                    do {
                        return (name, try await source(track), true)
                    } catch let error as DecodingError {
                        DebugLog.lyrics("Lyrics source \(index + 1) parsing failed: \(error.localizedDescription)")
                        DebugLog.lyricsDiagnostic("matcher.provider_result provider=\(name) result=error error_type=decoding line_count=0")
                        return (name, nil, false)
                    } catch let error as URLError {
                        DebugLog.lyrics("Lyrics source \(index + 1) network failed: \(error.localizedDescription)")
                        DebugLog.lyricsDiagnostic("matcher.provider_result provider=\(name) result=error error_type=url line_count=0")
                        return (name, nil, false)
                    } catch {
                        DebugLog.lyrics("Lyrics source \(index + 1) search failed: \(error.localizedDescription)")
                        DebugLog.lyricsDiagnostic("matcher.provider_result provider=\(name) result=error error_type=other line_count=0")
                        return (name, nil, false)
                    }
                }
            }
            var hadSuccessfulSource = false
            var emptySources = 0
            var failedSources = 0
            for await result in group {
                hadSuccessfulSource = hadSuccessfulSource || result.succeeded
                if let lines = result.lines, !lines.isEmpty {
                    DebugLog.lyricsDiagnostic("matcher.provider_result provider=\(result.name) result=hit error_type=none line_count=\(lines.count)")
                    DebugLog.lyricsDiagnostic("matcher.final selected_provider=\(result.name) aggregate_reason=hit successful_sources=1 empty_sources=\(emptySources) failed_sources=\(failedSources)")
                    group.cancelAll()
                    return SourceAggregate(lines: lines, hadSuccessfulSource: true, aggregateReason: "hit", selectedProvider: result.name)
                }
                if result.succeeded {
                    emptySources += 1
                    DebugLog.lyricsDiagnostic("matcher.provider_result provider=\(result.name) result=empty error_type=none line_count=0")
                } else {
                    failedSources += 1
                }
            }
            let reason = failedSources == sources.count ? "all_failed" : (emptySources > 0 && failedSources > 0 ? "mixed_empty_error" : "empty")
            DebugLog.lyricsDiagnostic("matcher.final selected_provider=none aggregate_reason=\(reason) successful_sources=0 empty_sources=\(emptySources) failed_sources=\(failedSources)")
            return SourceAggregate(lines: [], hadSuccessfulSource: hadSuccessfulSource, aggregateReason: reason, selectedProvider: nil)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
