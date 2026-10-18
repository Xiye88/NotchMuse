import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) {}
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) {}
    static func lyrics(_ text: String) {}
}
private actor Calls {
    private var counts: [String: Int] = [:]
    func next(_ key: String) -> Int { counts[key, default: 0] += 1; return counts[key]! }
    func count(_ key: String) -> Int { counts[key, default: 0] }
}
@main struct SpotifyIdentityRecoveryTests {
    static let uri = "spotify:track:5vNRhkKd0yEAg8suGBpjeY"
    static let raw = SpotifyTrack(name: "APT.", artist: "ROSÉ", album: "APT.", duration: 169.917)
    static let identity = SpotifyCanonicalIdentity(nativeTrackID: uri, title: "APT.", artists: ["ROSÉ", "Bruno Mars"], album: "", duration: 169.917, isrc: nil, identitySource: "Spotify public Embed URI response")
    static func candidate(artist: String = "ROSÉ, Bruno Mars", title: String = "APT.", last: Double = 160) -> LyricsCandidate {
        LyricsCandidate(document: TimedLyricDocument(lines: (0..<8).map { LyricLine(time: 6 + Double($0) * (last - 6) / 7, text: "Synthetic test phrase \($0)") }), provider: "NetEase", sourcePlatform: "netease", sourceTrackID: "2637558926", sourceTitle: title, sourceArtist: artist, sourceAlbum: "APT.", sourceDuration: 169.917, matcherScore: 100)
    }
    @MainActor static func main() async throws {
        var failures = 0, checks = 0
        func check(_ value: Bool, _ message: String) { checks += 1; if !value { failures += 1; print("FAIL: \(message)") } }
        let calls = Calls()
        let late = LyricsClient(candidateSources: [{ track in
            _ = await calls.next("source")
            return track.artist.contains("Bruno Mars") ? candidate() : nil
        }], names: ["NetEase"], identityResolver: { _ in
            _ = await calls.next("identity"); try await Task.sleep(for: .milliseconds(1450)); return identity
        })
        let recovered = try await late.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        check(!recovered.isEmpty && late.selectedCandidate?.sourceTrackID == "2637558926", "late same-URI collaborator evidence recovers joint recording beyond 1.2 seconds")
        check(late.diagnosticsText.contains("Artist: ROSÉ\n") && late.diagnosticsText.contains("Resolved Artist: ROSÉ, Bruno Mars"), "raw artist and supplementary artist both retained")
        check(late.diagnosticsText.contains("Spotify public Embed URI response"), "supplement provenance is explicit")
        _ = try await late.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let identityCalls = await calls.count("identity"), sourceCalls = await calls.count("source")
        check(identityCalls == 1 && sourceCalls == 2, "validated identity and positive candidate cache avoid repeat network")
        let fast = LyricsClient(candidateSources: [{ _ in candidate(artist: "ROSÉ") }], names: ["NetEase"], identityResolver: { _ in try await Task.sleep(for: .seconds(4)); return identity })
        let start = ProcessInfo.processInfo.systemUptime
        _ = try await fast.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        check(ProcessInfo.processInfo.systemUptime - start < 0.5, "already strict-valid primary winner does not wait for identity recovery")
        let arrived = LyricsClient(candidateSources: [{ track in
            try await Task.sleep(for: .milliseconds(40))
            return track.artist.contains("Bruno Mars") ? candidate() : candidate(artist: "ROSÉ")
        }], names: ["NetEase"], identityResolver: { _ in identity })
        _ = try await arrived.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        check(arrived.diagnosticsText.contains("Resolved Artist: ROSÉ, Bruno Mars"), "already-completed supplemental identity is not discarded by the fast path")
        let retryCalls = Calls()
        let retry = LyricsClient(candidateSources: [{ _ in
            if await retryCalls.next("source") == 1 { throw URLError(.networkConnectionLost) }
            return candidate(artist: "ROSÉ")
        }], names: ["NetEase"])
        let retryResult = try? await retry.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let retries = await retryCalls.count("source")
        check(retryResult?.isEmpty == false && retries == 2, "one transient source failure receives one bounded recovery attempt")
        let emptyCalls = Calls()
        let empty = LyricsClient(candidateSources: [{ _ in _ = await emptyCalls.next("source"); return nil }], names: ["NetEase"])
        _ = try? await empty.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let empties = await emptyCalls.count("source")
        check(empties == 1, "successful empty response is not retried")
        let wrongCalls = Calls()
        let wrong = LyricsClient(candidateSources: [{ _ in _ = await wrongCalls.next("source"); return candidate(artist: "Different Artist") }], names: ["NetEase"])
        _ = try? await wrong.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let wrongs = await wrongCalls.count("source")
        check(wrong.selectedCandidate == nil && wrongs == 1, "identity mismatch never triggers retry or relaxed matching")
        let timeline = LyricsClient(candidateSources: [{ _ in candidate(artist: "ROSÉ", last: 180) }], names: ["NetEase"])
        _ = try? await timeline.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        check(timeline.selectedCandidate == nil && timeline.diagnosticsText.contains("timeline_out_of_recording"), "out-of-recording timeline remains rejected")
        let identityRetries = Calls()
        let transientIdentity = LyricsClient(candidateSources: [{ track in track.artist.contains("Bruno Mars") ? candidate() : nil }], names: ["NetEase"], identityResolver: { _ in
            if await identityRetries.next("identity") == 1 { throw URLError(.networkConnectionLost) }; return identity
        })
        let joint = try? await transientIdentity.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let ir = await identityRetries.count("identity")
        check(joint?.isEmpty == false && ir == 2, "public identity transport transient failure retries once")
        let cancellationCalls = Calls()
        let cancelled = LyricsClient(candidateSources: [{ track in
            _ = await cancellationCalls.next(track.name)
            try await Task.sleep(for: .milliseconds(300)); return candidate(artist: "ROSÉ", title: track.name)
        }], names: ["NetEase"], identityResolver: { _ in try await Task.sleep(for: .seconds(4)); return identity })
        let old = Task { try await cancelled.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri) }
        try await Task.sleep(for: .milliseconds(30)); cancelled.clearDiagnostics("Resolution Status: stopped")
        _ = try? await old.value
        check(cancelled.selectedCandidate == nil && cancelled.diagnosticsText.contains("stopped"), "clear/exit cancellation cannot publish old selection")
        let persistent = Calls()
        let unavailable = LyricsClient(candidateSources: [{ _ in _ = await persistent.next("source"); throw URLError(.networkConnectionLost) }], names: ["NetEase"])
        _ = try? await unavailable.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let attempts = await persistent.count("source")
        check(attempts == 2, "persistent transient failure stops after two attempts")
        let validContext = LyricsSelectionContext(track: raw, playerSource: "Spotify", nativeTrackID: uri, isrc: nil)
        let primary = candidate(artist: "ROSÉ")
        check(LyricsSelection.select([primary], context: validContext).winner != nil, "control candidate passes existing strict selector")
        for error in [URLError(.cancelled), URLError(.cannotParseResponse), URLError(.badURL), URLError(.notConnectedToInternet)] {
            check(!LyricsHTTP.isTransient(error), "no automatic retry for \(error.code)")
        }
        check(LyricsHTTP.isTransient(URLError(.timedOut)), "timeout eligible for one recovery")
        for code in [401, 403, 404, 429, 500] {
            check(!LyricsHTTP.isTransient(LyricsHTTP.StatusError(code: code, retryAllowed: true)), "HTTP \(code) not retried")
        }
        check(LyricsHTTP.isTransient(LyricsHTTP.StatusError(code: 503, retryAllowed: true)), "temporary gateway unavailable eligible")
        check(!LyricsHTTP.isTransient(LyricsHTTP.StatusError(code: 503, retryAllowed: false)), "Retry-After defers request instead of immediate retry")
        let switched = LyricsClient(candidateSources: [{ track in
            if track.name == "APT." { try await Task.sleep(for: .milliseconds(300)) }
            return candidate(artist: "ROSÉ", title: track.name)
        }], names: ["NetEase"])
        let oldSong = Task { try await switched.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri) }
        try await Task.sleep(for: .milliseconds(25))
        let nextTrack = SpotifyTrack(name: "New Song", artist: "ROSÉ", album: "APT.", duration: 169.917)
        _ = try await switched.syncedLyrics(for: nextTrack, playerSource: "Spotify", nativeTrackID: "spotify:track:0VjIjW4GlUZAMYd2vXMi3b")
        _ = try? await oldSong.value
        check(switched.selectedCandidate?.sourceTitle == "New Song", "cancelled previous track cannot overwrite current track")
        let invalidCount = Calls()
        let invalid = LyricsClient(candidateSources: [{ track in track.artist.contains("Bruno Mars") ? candidate() : nil }], names: ["NetEase"], identityResolver: { _ in
            _ = await invalidCount.next("identity")
            return SpotifyCanonicalIdentity(nativeTrackID: "spotify:track:0VjIjW4GlUZAMYd2vXMi3b", title: "APT.", artists: ["ROSÉ", "Bruno Mars"], album: "", duration: 169.917, isrc: nil, identitySource: "Spotify public Embed URI response")
        })
        _ = try? await invalid.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let invalids = await invalidCount.count("identity")
        check(invalid.selectedCandidate == nil && invalids == 1, "wrong native URI neither supplements artist nor retries identity")
        let retryCancelCalls = Calls()
        let retryCancel = LyricsClient(candidateSources: [{ _ in _ = await retryCancelCalls.next("source"); throw URLError(.networkConnectionLost) }], names: ["NetEase"])
        let retrying = Task { try await retryCancel.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri) }
        try await Task.sleep(for: .milliseconds(50)); retrying.cancel(); _ = try? await retrying.value
        let cancelledAttempts = await retryCancelCalls.count("source")
        check(cancelledAttempts == 1, "cancellation during backoff prevents second request")
        let timeoutCalls = Calls()
        let timeoutRecovery = LyricsClient(candidateSources: [{ _ in
            let attempt = await timeoutCalls.next("source")
            try await Task.sleep(for: .milliseconds(20))
            if attempt == 1 { throw URLError(.timedOut) }
            return candidate(artist: "ROSÉ")
        }], names: ["NetEase"])
        let timeoutStart = ProcessInfo.processInfo.systemUptime
        let timeoutResult = try? await timeoutRecovery.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let timeouts = await timeoutCalls.count("source")
        check(timeoutResult?.isEmpty == false && timeouts == 2, "timed-out first source request recovers once within a fresh bounded source window")
        print("CONTROL source_timeout_recovery_ms=\((ProcessInfo.processInfo.systemUptime - timeoutStart) * 1000) attempts=\(timeouts) backoff_ms=150")
        let deadlineClient = LyricsClient(candidateSources: [{ _ in nil }], names: ["NetEase"], identityResolver: { _ in try await Task.sleep(for: .seconds(20)); return identity })
        let deadlineStart = ProcessInfo.processInfo.systemUptime
        _ = try? await deadlineClient.syncedLyrics(for: raw, playerSource: "Spotify", nativeTrackID: uri)
        let deadlineElapsed = ProcessInfo.processInfo.systemUptime - deadlineStart
        check(deadlineElapsed >= 5.8 && deadlineElapsed < 6.8 && deadlineClient.selectedCandidate == nil, "unresponsive identity stops at the six-second recovery deadline")
        print("CONTROL identity_deadline_ms=\(deadlineElapsed * 1000)")
        print("Identity recovery: \(checks - failures)/\(checks) PASS")
        if failures > 0 { exit(1) }
    }
}
