import Foundation
import LyricsCore

enum AppPreferences {
    static let language: AppLanguage = .english
}

struct TrackSpec: Sendable {
    let bucket: String
    let rawTitle: String
    let rawArtist: String
    let rawAlbum: String
    let duration: Double
    let isGuardInstrumental: Bool
}

struct EvalResult: Sendable {
    let spec: TrackSpec
    let sanitizedTitle: String
    let sanitizedArtist: String
    let matched: Bool
    let provider: String
    let lineCount: Int
    let latencyMs: Int
    let failureCategory: String
    let detail: String
}

enum PlatformProfile: String, CaseIterable, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case netease = "NetEase"
    case qqMusic = "QQ Music"
    case kugou = "Kugou"
    case soda = "Soda"
    case youtubeMusic = "YouTube Music"

    var usesSanitizer: Bool {
        self == .youtubeMusic || self == .kugou || self == .qqMusic || self == .soda
    }
    var isBrowserOrYouTube: Bool {
        self == .youtubeMusic
    }
    var relaxedDuration: Bool {
        self == .youtubeMusic
    }
}

@main
enum Benchmark7Platforms {
    static let instrumentalGuards: [TrackSpec] = [
        TrackSpec(bucket: "guard_inst", rawTitle: "River Flows in You", rawArtist: "Yiruma", rawAlbum: "First Love", duration: 218, isGuardInstrumental: true),
        TrackSpec(bucket: "guard_inst", rawTitle: "Kiss the Rain", rawArtist: "Yiruma", rawAlbum: "From The Yellow Room", duration: 256, isGuardInstrumental: true),
        TrackSpec(bucket: "guard_inst", rawTitle: "Clair de Lune", rawArtist: "Claude Debussy", rawAlbum: "Suite bergamasque", duration: 310, isGuardInstrumental: true),
        TrackSpec(bucket: "guard_inst", rawTitle: "Nocturne Op. 9 No. 2", rawArtist: "Frédéric Chopin", rawAlbum: "Nocturnes", duration: 270, isGuardInstrumental: true),
        TrackSpec(bucket: "guard_inst", rawTitle: "Summer", rawArtist: "Joe Hisaishi", rawAlbum: "Kikujiro", duration: 153, isGuardInstrumental: true)
    ]

    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            fputs("Usage: benchmark_7platforms <live_tracks.tsv> <ytm_100.tsv> [output_report.txt]\n", stderr)
            exit(2)
        }
        let livePath = args[1]
        let ytmPath = args[2]
        let reportPath = args.count >= 4 ? args[3] : nil

        do {
            let live100 = try loadLive100(from: livePath)
            let ytm100 = try loadYTM100(from: ytmPath)

            var fullReport = "=== NotchMuse 7-Platform x 100-Song Lyrics Benchmark ===\n"
            var summaryTable = "| Platform | Vocal Hit Rate | Overall (incl. 5 guards) | Guard False-Positives | Top Failure Causes |\n|---|---:|---:|---:|---|\n"

            let onlyPlatform = args.count >= 5 ? args[4] : nil
            let targetPlatforms = PlatformProfile.allCases.filter { onlyPlatform == nil || $0.rawValue.lowercased() == onlyPlatform!.lowercased() }
            for platform in targetPlatforms {
                let specs = buildPlatformDataset(platform: platform, live100: live100, ytm100: ytm100) + instrumentalGuards
                let results = await runWithConcurrency(rows: specs, maxConcurrency: 5) { spec in
                    await evaluate(spec: spec, platform: platform)
                }

                let vocal = results.filter { !$0.spec.isGuardInstrumental }
                let vocalHits = vocal.filter(\.matched)
                let guards = results.filter { $0.spec.isGuardInstrumental }
                let guardFPs = guards.filter(\.matched)
                let misses = vocal.filter { !$0.matched }

                var cats: [String: Int] = [:]
                for m in misses { cats[m.failureCategory, default: 0] += 1 }
                let topCats = cats.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")

                let vocalPct = Int(round(Double(vocalHits.count) * 100.0 / Double(max(1, vocal.count))))
                let overallHits = vocalHits.count + (guards.count - guardFPs.count)
                let overallPct = Int(round(Double(overallHits) * 100.0 / Double(max(1, results.count))))

                summaryTable += "| \(platform.rawValue) | \(vocalHits.count)/\(vocal.count) (\(vocalPct)%) | \(overallHits)/\(results.count) (\(overallPct)%) | \(guardFPs.count)/\(guards.count) | \(topCats.isEmpty ? "none" : topCats) |\n"

                var section = "\n--- \(platform.rawValue): \(vocalHits.count)/\(vocal.count) (\(vocalPct)%) | Guard FP: \(guardFPs.count)/\(guards.count) ---\n"
                if !cats.isEmpty {
                    section += "Miss breakdown: " + cats.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "\n"
                }
                for fp in guardFPs {
                    section += "  [GUARD_FP] \"\(fp.sanitizedTitle)\" - \"\(fp.sanitizedArtist)\" :: \(fp.detail)\n"
                }
                for m in misses {
                    section += "  [\(m.spec.bucket)] [\(m.failureCategory)] \"\(m.spec.rawTitle)\" | \"\(m.spec.rawArtist)\" | \(Int(m.spec.duration))s -> (\"\(m.sanitizedTitle)\" | \"\(m.sanitizedArtist)\") :: \(m.detail)\n"
                }
                fullReport += section
                fputs("Completed \(platform.rawValue): \(vocalHits.count)/\(vocal.count) (\(vocalPct)%) | Guard FP: \(guardFPs.count)/\(guards.count)\n", stderr)
            }

            let output = summaryTable + "\n" + fullReport
            if let reportPath {
                try output.write(toFile: reportPath, atomically: true, encoding: .utf8)
            }
            print(summaryTable)
        } catch {
            fputs("Benchmark failed: \(error)\n", stderr)
            exit(1)
        }
    }

    static func loadLive100(from path: String) throws -> [TrackSpec] {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 4, let dur = Double(cols[3]) else { return nil }
            return TrackSpec(bucket: "catalog", rawTitle: cols[0], rawArtist: cols[1], rawAlbum: cols[2], duration: dur, isGuardInstrumental: false)
        }
    }

    static func loadYTM100(from path: String) throws -> [TrackSpec] {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 5, let dur = Double(cols[4]) else { return nil }
            return TrackSpec(bucket: cols[0], rawTitle: cols[1], rawArtist: cols[2], rawAlbum: cols[3], duration: dur, isGuardInstrumental: false)
        }
    }

    static func buildPlatformDataset(platform: PlatformProfile, live100: [TrackSpec], ytm100: [TrackSpec]) -> [TrackSpec] {
        switch platform {
        case .youtubeMusic:
            return ytm100
        case .appleMusic:
            return live100.enumerated().map { idx, t in
                // Apple Music appends "- Single" on some albums
                let album = (idx % 5 == 0 && !t.rawAlbum.isEmpty) ? "\(t.rawAlbum) - Single" : t.rawAlbum
                return TrackSpec(bucket: t.bucket, rawTitle: t.rawTitle, rawArtist: t.rawArtist, rawAlbum: album, duration: t.duration, isGuardInstrumental: false)
            }
        case .spotify:
            return live100
        case .netease:
            return live100
        case .qqMusic:
            return live100.enumerated().map { idx, t in
                // QQ Music MediaRemote occasionally omits album
                let album = (idx % 4 == 0) ? "" : t.rawAlbum
                return TrackSpec(bucket: t.bucket, rawTitle: t.rawTitle, rawArtist: t.rawArtist, rawAlbum: album, duration: t.duration, isGuardInstrumental: false)
            }
        case .kugou:
            return live100.enumerated().map { idx, t in
                // Kugou MediaRemote omits album and frequently packs "Artist - Title" into title
                let packed = idx % 2 == 0
                return TrackSpec(
                    bucket: packed ? "kugou_packed" : "kugou_std",
                    rawTitle: packed ? "\(t.rawArtist) - \(t.rawTitle)" : t.rawTitle,
                    rawArtist: packed ? "" : t.rawArtist,
                    rawAlbum: "",
                    duration: t.duration,
                    isGuardInstrumental: false
                )
            }
        case .soda:
            return live100.enumerated().map { idx, t in
                let album = (idx % 3 == 0) ? "" : t.rawAlbum
                return TrackSpec(bucket: t.bucket, rawTitle: t.rawTitle, rawArtist: t.rawArtist, rawAlbum: album, duration: t.duration, isGuardInstrumental: false)
            }
        }
    }

    static func evaluate(spec: TrackSpec, platform: PlatformProfile) async -> EvalResult {
        let start = ContinuousClock.now
        let title: String
        let artist: String
        let album: String
        if platform.usesSanitizer {
            guard let san = MediaRemoteMetadataSanitizer.sanitize(
                title: spec.rawTitle,
                artist: spec.rawArtist,
                album: spec.rawAlbum,
                isBrowserOrYouTube: platform.isBrowserOrYouTube
            ) else {
                return EvalResult(spec: spec, sanitizedTitle: "", sanitizedArtist: "", matched: false, provider: "DROPPED", lineCount: 0, latencyMs: 0, failureCategory: "sanitizer_dropped", detail: "sanitizer nil")
            }
            title = san.title; artist = san.artist; album = san.album
        } else {
            title = spec.rawTitle; artist = spec.rawArtist; album = spec.rawAlbum
        }

        let track = SpotifyTrack(name: title, artist: artist, album: album, duration: spec.duration, relaxedDurationMatching: platform.relaxedDuration)
        let res = await runClient(track: track, playerSource: platform.rawValue)
        let elapsed = ms(since: start)
        return EvalResult(
            spec: spec,
            sanitizedTitle: title,
            sanitizedArtist: artist,
            matched: res.matched,
            provider: res.provider,
            lineCount: res.lineCount,
            latencyMs: elapsed,
            failureCategory: res.matched ? "OK" : classify(res.diagnostics),
            detail: res.summary
        )
    }

    @MainActor
    static func runClient(track: SpotifyTrack, playerSource: String) async -> (matched: Bool, provider: String, lineCount: Int, diagnostics: String, summary: String) {
        let client = LyricsClient(identityResolver: nil)
        do {
            let lines = try await client.syncedLyrics(for: track, bypassCache: true, playerSource: playerSource)
            let diag = client.selectionDiagnostics
            if lines.isEmpty {
                return (false, "MISS", 0, diag, extractSummary(diag))
            }
            let provider = client.selectedProvider ?? "unknown"
            return (true, provider, lines.count, diag, "matched:\(provider)(\(lines.count)L)")
        } catch {
            let diag = client.selectionDiagnostics
            return (false, "ERROR", 0, diag, "err:\(error) | \(extractSummary(diag))")
        }
    }

    static func extractSummary(_ diag: String) -> String {
        diag.split(whereSeparator: \.isNewline).map(String.init).filter {
            $0.hasPrefix("Sources:") || $0.hasPrefix("Rejected:") || $0.hasPrefix("No Lyrics Reason:")
        }.joined(separator: " | ")
    }

    static func classify(_ diag: String) -> String {
        let l = diag.lowercased()
        if l.contains("duration_risk") { return "duration_risk" }
        if l.contains("content_ambiguity") { return "content_ambiguity" }
        if l.contains("timeline_out_of_recording") { return "timeline_out_of_recording" }
        if l.contains("timeline_conflict") { return "timeline_conflict" }
        if l.contains("identity_ambiguous") { return "identity_ambiguous" }
        if l.contains("album_version_mismatch") || l.contains("version_mismatch") { return "version_mismatch" }
        if l.contains("artist_mismatch") { return "artist_mismatch" }
        if l.contains("title_mismatch") { return "title_mismatch" }
        if l.contains("resolver_metadata_unverified") { return "resolver_unverified" }
        return "provider_empty"
    }

    static func runWithConcurrency<T: Sendable, R: Sendable>(
        rows: [T], maxConcurrency: Int, work: @escaping @Sendable (T) async -> R
    ) async -> [R] {
        var results: [(Int, R)] = []
        results.reserveCapacity(rows.count)
        await withTaskGroup(of: (Int, R).self) { group in
            var next = 0
            for _ in 0..<min(maxConcurrency, rows.count) {
                let i = next; let item = rows[i]; next += 1
                group.addTask { (i, await work(item)) }
            }
            while let done = await group.next() {
                results.append(done)
                if next < rows.count {
                    let i = next; let item = rows[i]; next += 1
                    group.addTask { (i, await work(item)) }
                }
            }
        }
        return results.sorted { $0.0 < $1.0 }.map(\.1)
    }

    static func ms(since start: ContinuousClock.Instant) -> Int {
        let c = start.duration(to: .now).components
        return Int(c.seconds) * 1000 + Int(c.attoseconds / 1_000_000_000_000_000)
    }
}
