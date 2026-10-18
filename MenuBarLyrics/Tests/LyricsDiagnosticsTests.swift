import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) { }
    static func lyrics(_ text: String) { }
}
actor IdentityCalls {
    private(set) var count = 0
    func increment() { count += 1 }
}

@main struct LyricsDiagnosticsTests {
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        let uri = "spotify:track:0123456789012345678901"
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Player Album", duration: 200)
        let lines = (0..<10).map { index in
            let time = Double(index) * 18 + 10, text = "synthetic vocal line \(index)"
            return LyricLine(time: time, text: text, endTime: time + 2, segments: [LyricSegment(time: time, endTime: time + 2, text: text)])
        }
        let good = LyricsCandidate(document: TimedLyricDocument(lines: lines), provider: "Test", sourcePlatform: "qq", sourceTrackID: "1", sourceTitle: "Song", sourceArtist: "Artist", sourceAlbum: "Canonical Album", sourceDuration: 200, sourceISRC: "USZZZ2600001", matcherScore: 100)
        let bad = LyricsCandidate(document: good.document, provider: "Other", sourcePlatform: "qq", sourceTrackID: "2", sourceTitle: "Song", sourceArtist: "Artist", sourceAlbum: "Canonical Album", sourceDuration: 230, sourceISRC: "USZZZ2600001")
        let identity = SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song", artists: ["Artist"], album: "Canonical Album", duration: 200, isrc: "USZZZ2600001", identitySource: "official Spotify Get Track response")
        let client = LyricsClient(candidateSources: [{ _ in good }, { _ in bad }], names: ["Test", "Other"], identityResolver: { _ in
            try await Task.sleep(for: .milliseconds(40))
            return identity
        })
        check(client.diagnosticsText.contains("Track title: unavailable"), "no-track copy is explicit")
        let fresh = try await client.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri)
        check(fresh == good.document.normalizedLines && client.selectedCandidate?.provider == "Test", "diagnostics preserve selected lyrics")
        check(client.selectedDocument?.lines == good.document.lines && client.selectedDocument?.timingFidelity == .word, "diagnostics preserve rich line/token timing")
        let report = client.diagnosticsText
        for field in ["Track title: Song", "Artist: Artist", "Album: Player Album", "Resolved Album: Canonical Album", "Duration: 200.0 s", "Chosen Provider: Test", "Identity Tier: B exact ISRC", "Accepted / Rejected: accepted", "Accepted / Rejected: rejected", "Reason: duration_risk", "Duration Difference: 30.0 s", "First Lyric Timestamp: 10.0 s", "Timeline Conflict: false", "Cache Hit / Miss: miss", "Cache Source: none", "Timing Fidelity: word"] {
            check(report.contains(field), "missing diagnostics field: \(field)")
        }
        let latencyLine = report.components(separatedBy: "\n").first { $0.hasPrefix("Resolution Latency: ") }!
        let latency = Double(latencyLine.components(separatedBy: " ")[2])!
        check(latency >= 0.035, "latency includes identity resolution")
        let cached = try await client.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri)
        check(cached == fresh && client.diagnosticsText.contains("Cache Hit / Miss: hit (revalidated)") && client.diagnosticsText.contains("Cache Source: in-memory candidate cache / Test"), "cache result and source retained")
        _ = try await client.syncedLyrics(for: track, bypassCache: true, playerSource: "Spotify", nativeTrackID: uri)
        check(client.diagnosticsText.contains("bypassed (refresh)"), "refresh bypass explained")
        _ = try await client.syncedLyrics(for: track, exactSource: { _ in nil }, playerSource: "NetEaseMusic", nativeTrackID: "MR-1", isrc: "USZZZ2600001")
        check(client.diagnosticsText.contains("bypassed (live Exact-ID authorization)"), "live authorization cache bypass explained")
        let shifted = LyricsCandidate(document: TimedLyricDocument(lines: lines.map { LyricLine(time: $0.time + 8, text: $0.text) }), provider: "Shifted", sourcePlatform: "qq", sourceTrackID: "3", sourceTitle: "Song", sourceArtist: "Artist", sourceAlbum: "Canonical Album", sourceDuration: 200, sourceISRC: "USZZZ2600001")
        let conflict = LyricsClient(candidateSources: [{ _ in good }, { _ in shifted }], names: ["Test", "Shifted"], identityResolver: { _ in identity })
        check(try await conflict.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri).isEmpty && conflict.diagnosticsText.contains("Timeline Conflict: true") && conflict.diagnosticsText.contains("Reason: trusted_timeline_conflict"), "conflict remains No Lyrics with per-candidate explanation")
        let secrets = LyricsClient.sanitizedDiagnostics("Cookie: secret-cookie\naccess_token=secret-token\nclientSecret=secret-client\npassword: secret-password\nAccount: private@example.com\nEndpoint: https://example.com/?token=secret-query\nPath: /Users/private/local")
        check(!secrets.contains("secret-") && !secrets.contains("private@example.com") && !secrets.contains("/Users/private"), "credential/account/URL/path redaction")
        let oldID = client.diagnosticsRequestID
        client.setShadowDiagnostics("Shadow Status: completed", requestID: oldID)
        check(client.diagnosticsText.contains("Shadow Status: completed"), "same-request shadow appendix available")
        client.clearDiagnostics()
        client.setShadowDiagnostics("Shadow Status: stale", requestID: oldID)
        check(!client.diagnosticsText.contains("Shadow Status") && !client.diagnosticsText.contains("Track title: Song"), "cleared request refuses stale shadow and track metadata")
        let delayed = LyricsClient(candidateSources: [{ _ in
            try await Task.sleep(for: .milliseconds(80))
            return good
        }], names: ["Test"], identityResolver: { _ in identity })
        let pending = Task { try await delayed.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri) }
        try await Task.sleep(for: .milliseconds(20))
        check(delayed.diagnosticsText.contains("Track title: Song") && delayed.diagnosticsText.contains("Resolution Status: searching"), "search reports current immutable request metadata")
        delayed.clearDiagnostics()
        do { _ = try await pending.value; preconditionFailure("cleared request must cancel") }
        catch is CancellationError { checks += 1 }
        check(delayed.diagnosticsText.contains("no current playback selection") && !delayed.diagnosticsText.contains("Chosen Provider: Test"), "late local response does not overwrite cleared diagnostics")
        let cancelledID = client.diagnosticsRequestID
        let cancelledBeforeStart = Task { @MainActor in
            try await client.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri)
        }
        cancelledBeforeStart.cancel()
        do { _ = try await cancelledBeforeStart.value; preconditionFailure("cancelled caller must not start") }
        catch is CancellationError { checks += 1 }
        check(client.diagnosticsRequestID == cancelledID, "cancelled caller cannot clear newer request state")
        let invalidID = LyricsClient(candidateSources: [{ _ in nil }], names: ["Empty"])
        _ = try await invalidID.syncedLyrics(for: track, playerSource: "NetEaseMusic", nativeTrackID: "https://example.com/?token=secret-native")
        check(invalidID.diagnosticsText.contains("No Lyrics Reason: provider_missing") && invalidID.diagnosticsText.contains("[redacted unsupported identifier]") && !invalidID.diagnosticsText.contains("secret-native"), "unsupported native identifier is not copied")
        let boundedStarted = ProcessInfo.processInfo.systemUptime
        let bounded = await LyricsClient.collect([{ _ in try await Task.sleep(for: .seconds(10)); return good }], names: ["Slow"], for: track, window: 0.08, context: nil, boundedSpotify: true)
        check(ProcessInfo.processInfo.systemUptime - boundedStarted < 0.3 && bounded.candidates.isEmpty, "source deadline cancels cooperative old network task")
        let cacheStarted = ProcessInfo.processInfo.systemUptime
        for _ in 0..<10 { _ = try await client.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri) }
        check(ProcessInfo.processInfo.systemUptime - cacheStarted < 0.3, "ten warm exact-URI resolutions skip network identity calls")
        check(client.diagnosticsText.contains("identity_cache_hit"), "validated identity cache hit reported")
        let failedCalls = IdentityCalls()
        let cachedNative = LyricsClient(candidateSources: [{ _ in good }], names: ["Test"], identityResolver: { _ in
            await failedCalls.increment(); throw URLError(.resourceUnavailable)
        })
        let matchingNative = SpotifyTrack(name: "Song", artist: "Artist", album: "Canonical Album", duration: 200)
        _ = try await cachedNative.syncedLyrics(for: matchingNative, playerSource: "Spotify", nativeTrackID: uri)
        try await Task.sleep(for: .milliseconds(5100))
        let laterWarmStart = ProcessInfo.processInfo.systemUptime
        _ = try await cachedNative.syncedLyrics(for: matchingNative, playerSource: "Spotify", nativeTrackID: uri)
        let identityCalls = await failedCalls.count
        check(identityCalls == 1 && ProcessInfo.processInfo.systemUptime - laterWarmStart < 0.3, "exact lyric cache skips identity network even after short failure-cache TTL expires")
        let fastStart = ProcessInfo.processInfo.systemUptime
        let fastContext = LyricsSelectionContext(track: matchingNative, playerSource: "Spotify", nativeTrackID: uri, isrc: "USZZZ2600001")
        let fast = await LyricsClient.collect([{ _ in good }, { _ in try await Task.sleep(for: .seconds(10)); return nil }],
            names: ["Test", "LRCMux"], for: matchingNative, window: 1, context: fastContext, boundedSpotify: true)
        check(ProcessInfo.processInfo.systemUptime - fastStart < 0.3 && LyricsSelection.select(fast.candidates, context: fastContext).tier == "B exact ISRC", "strict direct winner does not wait for deep unbound resolver")
        for _ in 0..<10 {
            let old = Task { try await delayed.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri) }
            try await Task.sleep(for: .milliseconds(5))
            let nextTrack = SpotifyTrack(name: "Next", artist: "Artist", album: "Player Album", duration: 200)
            _ = try await delayed.syncedLyrics(for: nextTrack, playerSource: "Spotify", nativeTrackID: "spotify:track:2222222222222222222222")
            do { _ = try await old.value; preconditionFailure("old track must cancel") }
            catch is CancellationError { checks += 1 }
            check(delayed.selectedCandidate == nil && delayed.diagnosticsText.contains("Track title: Next"), "old request cannot overwrite next track state/cache")
        }
        print("PASS: \(checks) lyrics diagnostics checks; synthetic tests are not listening acceptance")
    }
}
