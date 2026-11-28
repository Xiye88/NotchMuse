import CryptoKit
import Foundation
import LyricsCore

enum AppPreferences {
    static let language: AppLanguage = .english
}

struct TrackSpec: Sendable {
    let id: String
    let bucket: String
    let title: String
    let artist: String
    let album: String
    let duration: Double

    var isGuard: Bool { bucket == "guard_inst" }
}

struct EvalResult: Encodable, Sendable {
    let platform: String
    let id: String
    let bucket: String
    let inputTitle: String
    let inputArtist: String
    let inputDuration: Double
    let title: String
    let artist: String
    let matched: Bool
    let guardTrack: Bool
    let provider: String?
    let sourceID: String?
    let sourceTitle: String?
    let sourceArtist: String?
    let sourceAlbum: String?
    let sourceDuration: Double?
    let lineCount: Int
    let firstLine: Double?
    let lastLine: Double?
    let timelineDigest: String?
    let category: String
    let detail: String
}

@main
enum Benchmark7Platforms {
    static let platforms: [PlayerSource] = [
        .appleMusic, .spotify, .netEaseMusic, .qqMusic, .sodaMusic, .kugouMusic, .youtubeMusic
    ]
    static let legacyGuards: [TrackSpec] = [
        TrackSpec(id: "guard-1", bucket: "guard_inst", title: "River Flows in You", artist: "Yiruma", album: "First Love", duration: 218),
        TrackSpec(id: "guard-2", bucket: "guard_inst", title: "Kiss the Rain", artist: "Yiruma", album: "From The Yellow Room", duration: 256),
        TrackSpec(id: "guard-3", bucket: "guard_inst", title: "Clair de Lune", artist: "Claude Debussy", album: "Suite bergamasque", duration: 310),
        TrackSpec(id: "guard-4", bucket: "guard_inst", title: "Nocturne Op. 9 No. 2", artist: "Frédéric Chopin", album: "Nocturnes", duration: 270),
        TrackSpec(id: "guard-5", bucket: "guard_inst", title: "Summer", artist: "Joe Hisaishi", album: "Kikujiro", duration: 153)
    ]

    struct InvalidInput: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args == ["--help"] {
                print("Usage: benchmark_7platforms --catalog tracks.tsv --ytm ytm.tsv [--concurrency 4] [--report report.md] [--rows results.jsonl] [--http-cache directory] [--platform 'Apple Music'] [--limit 10]")
                return
            }
            var options: [String: String] = [:]
            if args.first?.hasPrefix("--") == true {
                let flags = ["--catalog", "--ytm", "--concurrency", "--report", "--rows", "--platform", "--limit", "--http-cache"]
                guard args.count % 2 == 0 else { throw InvalidInput("Each option requires a value") }
                for index in stride(from: 0, to: args.count, by: 2) {
                    guard flags.contains(args[index]) else { throw InvalidInput("Unknown option \(args[index])") }
                    options[args[index]] = args[index + 1]
                }
            } else if (2...4).contains(args.count) {
                for (flag, value) in zip(["--catalog", "--ytm", "--report", "--platform"], args) {
                    options[flag] = value
                }
            }
            guard let catalogPath = options["--catalog"], let ytmPath = options["--ytm"],
                  let concurrency = Int(options["--concurrency"] ?? "4"), (1...4).contains(concurrency),
                  let limit = Int(options["--limit"] ?? "\(Int.max)"), limit > 0 else {
                throw InvalidInput("Provide --catalog and --ytm; --concurrency must be 1–4 and --limit positive")
            }
            let aliases: [String: PlayerSource] = ["netease": .netEaseMusic, "soda": .sodaMusic, "kugou": .kugouMusic]
            let selectedPlatforms: [PlayerSource]
            if let filter = options["--platform"]?.lowercased() {
                guard let platform = platforms.first(where: { $0.rawValue.lowercased() == filter }) ?? aliases[filter] else {
                    throw InvalidInput("Unknown platform \(filter)")
                }
                selectedPlatforms = [platform]
            } else {
                selectedPlatforms = platforms
            }
            var catalog = try load(catalogPath)
            var youtube = try load(ytmPath)
            if catalog.allSatisfy({ !$0.isGuard }) { catalog += legacyGuards }
            if youtube.allSatisfy({ !$0.isGuard }) { youtube += legacyGuards }
            guard catalog.count == youtube.count,
                  zip(catalog, youtube).allSatisfy({ $0.id == $1.id && $0.isGuard == $1.isGuard }) else {
                throw InvalidInput("Catalog and YouTube rows must have the same ordered recording IDs and guard labels")
            }
            if let path = options["--http-cache"] {
                try await BenchmarkLyricsHTTP.shared.enableDiskCache(path)
            }
            let indices = catalog.indices.filter { catalog[$0].isGuard } +
                Array(catalog.indices.filter { !catalog[$0].isGuard }.prefix(limit))
            let catalogRows = catalog
            let youtubeRows = youtube
            let output: FileHandle?
            if let path = options["--rows"] {
                try Data().write(to: URL(fileURLWithPath: path))
                output = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            } else {
                output = nil
            }
            defer { try? output?.close() }
            var results: [EvalResult] = []
            let encoder = JSONEncoder()
            try await withThrowingTaskGroup(of: [EvalResult].self) { group in
                var remaining = indices.makeIterator()
                func enqueue() {
                    guard let index = remaining.next() else { return }
                    group.addTask {
                        var batch: [EvalResult] = []
                        for platform in selectedPlatforms {
                            let spec = platform == .youtubeMusic ? youtubeRows[index] : catalogRows[index]
                            batch.append(await evaluate(spec, index: index, platform: platform))
                        }
                        return batch
                    }
                }
                for _ in 0..<concurrency { enqueue() }
                while let batch = try await group.next() {
                    results += batch
                    if let output {
                        for row in batch {
                            try output.write(contentsOf: try encoder.encode(row) + Data([10]))
                        }
                    }
                    let completed = results.count / selectedPlatforms.count
                    if completed % 20 == 0 || completed == indices.count {
                        fputs("\(completed)/\(indices.count) recordings across \(selectedPlatforms.count) platforms\n", stderr)
                    }
                    enqueue()
                }
            }
            let summary = await BenchmarkLyricsHTTP.shared.summary()
            var report = "| Platform | Vocal selections | Guard false positives | Vocal miss breakdown |\n|---|---:|---:|---|\n"
            for platform in selectedPlatforms {
                let rows = results.filter { $0.platform == platform.rawValue }
                let guards = rows.filter(\.guardTrack)
                let vocal = rows.filter { !$0.guardTrack }
                let misses = Dictionary(grouping: vocal.filter { !$0.matched }, by: \.category)
                let breakdown = misses.sorted { (-$0.value.count, $0.key) < (-$1.value.count, $1.key) }
                    .map { "\($0.key)=\($0.value.count)" }.joined(separator: ", ")
                let hits = vocal.filter(\.matched).count
                let pct = String(format: "%.1f", 100 * Double(hits) / Double(vocal.count))
                report += "| \(platform.rawValue) | \(hits)/\(vocal.count) (\(pct)%) | \(guards.filter(\.matched).count)/\(guards.count) | \(breakdown) |\n"
            }
            report += "\n\(summary)\n"
            if let path = options["--report"] {
                try report.write(toFile: path, atomically: true, encoding: .utf8)
            }
            print(report)
        } catch {
            fputs("Benchmark failed: \(error)\n", stderr)
            exit(1)
        }
    }

    static func load(_ path: String) throws -> [TrackSpec] {
        let lines = try String(contentsOfFile: path, encoding: .utf8).split { $0 == "\n" || $0 == "\r\n" }
        guard let header = lines.first else { throw InvalidInput("Empty fixture \(path)") }
        let columns = header.split(separator: "\t").map(String.init)
        var ids = Set<String>()
        let rows = try lines.dropFirst().enumerated().map { index, line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == columns.count else { throw InvalidInput("Wrong column count at \(path):\(index + 2)") }
            let values = Dictionary(zip(columns, fields), uniquingKeysWith: { first, _ in first })
            guard let title = values["title"], !title.isEmpty, let artist = values["artist"], let album = values["album"],
                  let rawDuration = values["duration_seconds"], let duration = Double(rawDuration), duration.isFinite, duration > 0 else {
                throw InvalidInput("Invalid metadata at \(path):\(index + 2)")
            }
            let id = values["itunes_track_id"] ?? String(index)
            guard !id.isEmpty, ids.insert(id).inserted else { throw InvalidInput("Missing or duplicate ID \(id) in \(path)") }
            return TrackSpec(id: id, bucket: values["bucket"] ?? "catalog", title: title, artist: artist, album: album, duration: duration)
        }
        guard rows.contains(where: { !$0.isGuard }) else { throw InvalidInput("No vocal rows in \(path)") }
        return rows
    }

    static func snapshot(_ spec: TrackSpec, index: Int, platform: PlayerSource) -> MusicPlayerSnapshot {
        let tab = "\u{1F}"
        switch platform {
        case .appleMusic:
            let album = index % 5 == 0 && !spec.album.hasSuffix(" - Single") ? spec.album + " - Single" : spec.album
            return AppleMusicAdapter.parse(["playing", spec.title, spec.artist, album, String(spec.duration), "0", ""].joined(separator: tab))
        case .spotify:
            let payload = ["playing", spec.title, spec.artist, spec.album, String(spec.duration * 1000), "0"].joined(separator: tab)
            return SpotifyAdapter.snapshot(from: SpotifyReader.parse(payload))
        default:
            let packed = platform == .kugouMusic && index % 2 == 0
            let title = packed ? "\(spec.artist) - \(spec.title)" : spec.title
            let omitAlbum = platform == .kugouMusic || (platform == .qqMusic && index % 4 == 0) ||
                (platform == .sodaMusic && index % 3 == 0)
            guard let bundle = platform == .youtubeMusic ? "com.google.Chrome" : platform.bundleIdentifier else {
                return .unavailable
            }
            let event = MediaRemoteEvent(bundleIdentifier: bundle, playing: true, title: title, artist: packed ? nil : spec.artist,
                                         album: omitAlbum ? nil : spec.album, duration: spec.duration)
            if platform == .netEaseMusic {
                return NetEaseMusicAdapter.snapshot(from: event, isRunning: true)
            }
            return MediaRemotePlayerAdapter.snapshot(from: event, source: platform, isRunning: true)
        }
    }

    @MainActor
    static func evaluate(_ spec: TrackSpec, index: Int, platform: PlayerSource) async -> EvalResult {
        let track = snapshot(spec, index: index, platform: platform).currentTrack
        let client = LyricsClient(identityResolver: nil)
        var lyrics: [LyricLine] = []
        var failure: String?
        if let track {
            do {
                lyrics = try await client.syncedLyrics(for: track.spotifyTrack, bypassCache: true,
                    playerSource: track.playerSource.rawValue, nativeTrackID: track.nativeTrackID, isrc: track.isrc)
            } catch {
                failure = error as? LyricsClientError == .timeout ? "provider_timeout" : "provider_transport"
            }
        }
        let diagnostics = client.selectionDiagnostics
        let detail = diagnostics.split(whereSeparator: \.isNewline).filter { line in
            ["Sources:", "Rejected:", "No Lyrics Reason:", "Identity Tier:", "Top reject reason:"].contains { line.hasPrefix($0) }
        }.joined(separator: " | ")
        let candidate = client.selectedCandidate
        let category = track == nil ? "adapter_dropped" : lyrics.isEmpty ? classify(detail, failure: failure) : "selected"
        let timeline = lyrics.map { "\($0.time)\u{1F}\($0.text)" }.joined(separator: "\u{1E}")
        let timelineDigest = lyrics.isEmpty ? nil : SHA256.hash(data: Data(timeline.utf8)).description
        return EvalResult(platform: platform.rawValue, id: spec.id, bucket: spec.bucket,
                          inputTitle: spec.title, inputArtist: spec.artist, inputDuration: spec.duration,
                          title: track?.title ?? "", artist: track?.artist ?? "", matched: !lyrics.isEmpty,
                          guardTrack: spec.isGuard, provider: candidate?.provider, sourceID: candidate?.sourceTrackID,
                          sourceTitle: candidate?.sourceTitle, sourceArtist: candidate?.sourceArtist,
                          sourceAlbum: candidate?.sourceAlbum, sourceDuration: candidate?.sourceDuration,
                          lineCount: lyrics.count, firstLine: lyrics.first?.time, lastLine: lyrics.last?.time,
                          timelineDigest: timelineDigest, category: category, detail: detail)
    }

    static func classify(_ diagnostics: String, failure: String?) -> String {
        let detail = diagnostics.lowercased()
        for category in ["instrumental_recording", "unverified_user_contribution", "content_ambiguity", "timeline_out_of_recording", "timeline_conflict", "identity_ambiguous",
                         "duration_mismatch", "duration_risk", "version_mismatch", "artist_mismatch",
                         "title_mismatch", "source_duration_unknown", "resolver_metadata_unverified"] where detail.contains(category) {
            return category
        }
        return failure ?? "provider_empty"
    }
}
