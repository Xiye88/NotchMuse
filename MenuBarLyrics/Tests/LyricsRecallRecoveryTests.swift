import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) {}
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) {}
    static func lyrics(_ text: String) {}
}

@main struct LyricsRecallRecoveryTests {
    @MainActor static func main() async throws {
        var checks = 0, failures = 0
        func check(_ value: Bool, _ message: String) {
            checks += 1
            if !value { failures += 1; print("FAIL: \(message)") }
        }
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        let context = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "spotify:track:SP", isrc: nil)
        let vocals = (0..<8).map { LyricLine(time: 10 + Double($0) * 22, text: "Actual vocal phrase \($0)") }
        func make(_ provider: String, album: String? = "Album", lines: [LyricLine]? = nil,
                  title: String = "Song", duration: Double = 200, platform: String? = nil) -> LyricsCandidate {
            LyricsCandidate(document: TimedLyricDocument(lines: lines ?? vocals), provider: provider,
                sourcePlatform: platform ?? provider.lowercased(), sourceTrackID: "catalog-\(provider)",
                sourceTitle: title, sourceArtist: "Artist", sourceAlbum: album, sourceDuration: duration, matcherScore: 100)
        }
        let simplified = (0..<8).map { LyricLine(time: 10 + Double($0) * 22, text: "远方温柔的风景\($0)") }
        let traditional = (0..<8).map { LyricLine(time: 10.15 + Double($0) * 22, text: "遠方溫柔的風景\($0)") }
        check(LyricsSelection.select([make("NetEase", lines: simplified), make("LRCLIB", lines: traditional)], context: context).winner != nil,
              "reversible lyric spelling must not manufacture a whole-pool content conflict")
        let hair = (0..<8).map { LyricLine(time: 10 + Double($0) * 22, text: "髮型變化\($0)") }
        let emit = (0..<8).map { LyricLine(time: 10 + Double($0) * 22, text: "發型變化\($0)") }
        check(LyricsSelection.select([make("NetEase", lines: hair), make("QQ", lines: emit)], context: context).winner == nil,
              "ambiguous traditional characters must remain distinct")
        let unknown = make("Kugou", album: nil)
        let release = make("QQ", album: "Other release")
        check(LyricsSelection.select([unknown, release], context: context).winner != nil,
              "independent aligned direct recordings recover even when release labels differ")
        check(LyricsSelection.select([release], context: context).winner == nil,
              "a lone different release cannot establish the recording")
        check(LyricsSelection.select([unknown, make("LRCMux", album: "Other release", platform: "kugou")], context: context).winner == nil,
              "resolver aliases never manufacture independent confidence")
        check(LyricsSelection.select([unknown, make("QQ", album: "Other release", title: "Song (Live)")], context: context).winner == nil,
              "album recovery cannot override a Live versus studio contradiction")
        check(LyricsSelection.select([unknown, make("QQ", album: "Other release", duration: 207)], context: context).winner == nil,
              "album recovery cannot override risky duration")
        let conflicting = vocals.map { LyricLine(time: $0.time + 14, text: $0.text) }
        check(LyricsSelection.select([make("NetEase"), make("QQ", lines: conflicting)], context: context).winner == nil,
              "equally album-bound conflicting recordings remain rejected")
        let weakConflict = make("LRCLIB", album: "Compilation", lines: conflicting)
        check(LyricsSelection.select([make("NetEase"), weakConflict], context: context).winner?.provider == "NetEase",
              "a lower-confidence release cannot veto an album-bound full recording")
        var brokenEnd = vocals
        brokenEnd[7] = LyricLine(time: 164, text: "Actual vocal phrase 7", endTime: 400,
                                segments: [LyricSegment(time: 164, endTime: 400, text: "Actual vocal phrase 7")])
        let damaged = make("Kugou", album: nil, lines: brokenEnd)
        let recovered = LyricsSelection.select([damaged, release], context: context)
        check(recovered.winner != nil && recovered.winner!.document.normalizedLines.allSatisfy { ($0.endTime ?? $0.time) <= 202 },
              "independently aligned recording can downgrade malformed rich ends without losing valid line starts")
        check(LyricsSelection.select([damaged], context: context).winner == nil,
              "malformed rich timing is not repaired without independent recording evidence")
        let overrun = make("Kugou", album: nil, lines: vocals + [LyricLine(time: 230, text: "Actual extra verse")])
        check(LyricsSelection.select([overrun, release], context: context).winner == nil,
              "actual out-of-recording vocal starts are never clipped to recover recall")
        let lrcA = vocals.map { String(format: "[%02d:%05.2f]%@", Int($0.time) / 60, $0.time.truncatingRemainder(dividingBy: 60), $0.text) }.joined(separator: "\n")
        let lrcB = vocals.map { String(format: "[%02d:%05.2f]%@", Int($0.time) / 60, ($0.time + 0.1).truncatingRemainder(dividingBy: 60), $0.text) }.joined(separator: "\n")
        let uploads: [[String: Any]] = [
            ["id": 1, "trackName": "Song", "artistName": "Artist", "albumName": "Album", "duration": 200, "syncedLyrics": lrcA],
            ["id": 2, "trackName": "Song", "artistName": "Artist", "albumName": "Album", "duration": 201.5, "syncedLyrics": lrcB]
        ]
        let data = try JSONSerialization.data(withJSONObject: uploads)
        check(try LRCLIBLyricsSource().parseCandidate(data, for: track) != nil,
              "same-recording uploads with rounding and subsecond timing must survive provider dedup")
        var wrongUploads = uploads
        wrongUploads[1]["syncedLyrics"] = lrcB.replacingOccurrences(of: "Actual vocal phrase", with: "Entirely different lyrics")
        check(try LRCLIBLyricsSource().parseCandidate(JSONSerialization.data(withJSONObject: wrongUploads), for: track) == nil,
              "provider dedup cannot hide genuinely incompatible uploads")
        let networkNetEase = make("NetEase"), networkQQ = make("QQ")
        let primaryStarted = ProcessInfo.processInfo.systemUptime
        let staged = await LyricsClient.collect([
            { _ in nil }, { _ in networkNetEase }, { _ in nil },
            { _ in networkQQ }, { _ in unknown },
            { _ in try await Task.sleep(for: .seconds(5)); return nil }
        ], names: ["LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou", "Soda"], for: track,
            window: 2.85, context: context, boundedSpotify: true)
        check(ProcessInfo.processInfo.systemUptime - primaryStarted < 0.35 && LyricsSelection.select(staged.candidates, context: context).winner != nil,
              "a validated direct recording must not wait for an unproductive supplemental source")
        let lateConflict = make("LRCLIB", lines: conflicting)
        let primaryConflict = await LyricsClient.collect([
            { _ in try await Task.sleep(for: .milliseconds(100)); return lateConflict },
            { _ in networkNetEase }, { _ in nil }, { _ in nil }, { _ in nil }
        ], names: ["LRCLIB", "NetEase", "LRCMux", "QQ", "Kugou"], for: track,
            window: 1, context: context, boundedSpotify: true)
        check(LyricsSelection.select(primaryConflict.candidates, context: context).winner == nil,
              "fast generic output must wait for a pending primary provider and preserve its conflict")
        let available = RecoveryAvailability()
        let recovery = LyricsClient(candidateSources: [{ _ in
            guard await available.online else { throw URLError(.notConnectedToInternet) }
            return networkNetEase
        }], names: ["NetEase"], identityResolver: { _ in throw URLError(.resourceUnavailable) })
        do { _ = try await recovery.syncedLyrics(for: track, playerSource: "Spotify") } catch { }
        check(recovery.selectedCandidate == nil, "offline failure cannot retain a selected lyric")
        await available.restore()
        let restored = try await recovery.syncedLyrics(for: track, bypassCache: true, playerSource: "Spotify")
        check(!restored.isEmpty && recovery.selectedProvider == "NetEase", "Refresh recovers after transport restoration without restarting the app")
        _ = try await recovery.syncedLyrics(for: track, playerSource: "Spotify")
        check(recovery.diagnosticsText.contains("hit (revalidated)"), "recovered recording returns through validated cache")
        print("Recall recovery: \(checks - failures)/\(checks) PASS")
        if failures > 0 { exit(1) }
    }
}

private actor RecoveryAvailability {
    private(set) var online = false
    func restore() { online = true }
}
