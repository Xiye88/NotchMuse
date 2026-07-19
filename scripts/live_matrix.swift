import Foundation

private struct MatrixResult {
    let track: SpotifyTrack
    let source: String
    let lineCount: Int
    let latencyMilliseconds: Int

    var tsv: String {
        [track.name, track.artist, source, String(lineCount), String(latencyMilliseconds)].joined(separator: "\t")
    }
}

private enum SourceResult {
    case hit(String, [LyricLine])
    case empty
    case error
}

@main enum LiveMatrix {
    static func main() async {
        guard CommandLine.arguments.count == 3 else { exit(2) }

        do {
            let tracks = try loadTracks(from: URL(fileURLWithPath: CommandLine.arguments[1]))
            let results = await runMatrix(for: tracks)
            let report = (["title\tartist\tsource\tline_count\tlatency_ms"] + results.map(\.tsv)).joined(separator: "\n") + "\n"
            try report.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), atomically: true, encoding: .utf8)
            printSummary(for: results)

            guard results.filter({ $0.source != "MISS" && $0.source != "ERROR" }).count >= 90 else { exit(1) }
        } catch {
            fputs("Live matrix failed: \(error)\n", stderr)
            exit(2)
        }
    }

    private static func loadTracks(from url: URL) throws -> [SpotifyTrack] {
        let rows = try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline)
        guard rows.first == "title\tartist\talbum\tduration_seconds" else {
            throw MatrixError.invalidFixture
        }

        let tracks = try rows.dropFirst().map { row -> SpotifyTrack in
            let fields = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 4, let duration = Double(fields[3]), duration > 0 else {
                throw MatrixError.invalidFixture
            }
            return SpotifyTrack(name: String(fields[0]), artist: String(fields[1]), album: String(fields[2]), duration: duration)
        }
        guard tracks.count == 100 else { throw MatrixError.invalidFixture }
        return tracks
    }

    private static func runMatrix(for tracks: [SpotifyTrack]) async -> [MatrixResult] {
        var results = [MatrixResult]()
        for track in tracks {
            results.append(await fetchLyrics(for: track))
        }
        return results
    }

    private static func fetchLyrics(for track: SpotifyTrack) async -> MatrixResult {
        let start = ContinuousClock.now
        let result = await withTaskGroup(of: SourceResult.self, returning: (String, [LyricLine]?).self) { group in
            group.addTask { await sourceResult("LRCLIB") { try await LRCLIBLyricsSource().syncedLyrics(for: track) } }
            group.addTask { await sourceResult("NetEase") { try await NetEaseLyricsSource().syncedLyrics(for: track) } }
            group.addTask { await sourceResult("LRCMux") { try await LRCMuxLyricsSource().syncedLyrics(for: track) } }
            group.addTask { await sourceResult("QQ") { try await QQMusicLyricsSource().syncedLyrics(for: track) } }
            group.addTask { await sourceResult("Kugou") { try await KugouLyricsSource().syncedLyrics(for: track) } }
            group.addTask { await sourceResult("Soda") { try await SodaMusicLyricsSource().syncedLyrics(for: track) } }
            var hadError = false
            for await result in group {
                switch result {
                case let .hit(source, lines):
                    group.cancelAll()
                    return (source, lines)
                case .empty:
                    break
                case .error:
                    hadError = true
                }
            }
            return (hadError ? "ERROR" : "MISS", nil)
        }
        let components = start.duration(to: .now).components
        let milliseconds = Int(components.seconds) * 1_000 + Int(components.attoseconds / 1_000_000_000_000_000)
        return MatrixResult(track: track, source: result.0, lineCount: result.1?.count ?? 0, latencyMilliseconds: milliseconds)
    }

    private static func sourceResult(_ source: String, fetch: @escaping @Sendable () async throws -> [LyricLine]) async -> SourceResult {
        do {
            let lines = try await fetch()
            return lines.isEmpty ? .empty : .hit(source, lines)
        } catch {
            return .error
        }
    }

    private static func printSummary(for results: [MatrixResult]) {
        let hits = results.filter { $0.source != "MISS" && $0.source != "ERROR" }
        let errors = results.count { $0.source == "ERROR" }
        let misses = results.count { $0.source == "MISS" }
        let sourceCounts = ["LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"].map { source in
            "\(source)=\(hits.count { $0.source == source })"
        }.joined(separator: ", ")
        let latencies = results.map(\.latencyMilliseconds).sorted()
        let median = (latencies[(latencies.count - 1) / 2] + latencies[latencies.count / 2]) / 2
        let p95 = latencies[Int(ceil(Double(latencies.count) * 0.95)) - 1]

        print("Coverage: \(hits.count)/\(results.count)")
        print("Sources: \(sourceCounts)")
        print("ERROR: \(errors), MISS: \(misses)")
        print("Latency: median \(median) ms, p95 \(p95) ms")
        print(hits.count >= 90 ? "Live matrix passed: \(hits.count)/\(results.count) songs matched" : "Live matrix failed: \(hits.count)/\(results.count) songs matched")
    }

    private enum MatrixError: Error {
        case invalidFixture
    }
}
