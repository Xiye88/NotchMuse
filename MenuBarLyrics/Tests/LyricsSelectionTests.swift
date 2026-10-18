import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) { }
    static func lyrics(_ text: String) { }
}

actor SelectionCalls {
    private(set) var count = 0
    func record() { count += 1 }
}

@main struct LyricsSelectionTests {
    @MainActor static func main() async throws {
        var checks = 0, failures = 0
        func check(_ ok: Bool, _ message: String) {
            checks += 1
            if !ok { failures += 1; print("FAIL: \(message)") }
        }
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        let netease = LyricsSelectionContext(track: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR-generation", isrc: nil)
        func lines(_ shift: Double = 0, count: Int = 8, prefix: String = "Vocal phrase") -> [LyricLine] {
            (0..<count).map { LyricLine(time: 10 + Double($0) * 5 + shift, text: "\(prefix) \($0)") }
        }
        func candidate(_ provider: String, platform: String? = nil, id: String? = nil,
                       text: [LyricLine]? = nil, duration: Double? = 200, title: String = "Song",
                       album: String? = "Album", isrc: String? = nil, verified: Bool = false) -> LyricsCandidate {
            LyricsCandidate(document: TimedLyricDocument(lines: text ?? lines()), provider: provider,
                sourcePlatform: platform, sourceTrackID: id, sourceTitle: title, sourceArtist: "Artist",
                sourceAlbum: album, sourceDuration: duration, sourceISRC: isrc, matcherScore: 100,
                liveIdentityVerified: verified)
        }
        let generic = candidate("LRCLIB", platform: "lrclib", id: "catalog", text: lines(14))
        let exact = candidate("NetEaseExactID (Preview)", platform: "netease", id: "actual-catalog", verified: true)
        check(netease.platform == "netease", "actual player raw value maps to NetEase namespace")
        check(LyricsSelection.select([generic, exact], context: netease).winner == exact, "verified catalog identity defeats earlier conflicting generic")
        check(LyricsSelection.select([generic, candidate("QQ", platform: "qq", text: lines())], context: netease).winner == nil, "generic shifted timeline fails closed")
        check(LyricsSelection.select([candidate("LRCLIB"), candidate("QQ", text: lines(prefix: "Entirely different words"))], context: netease).winner == nil, "disjoint lyric bodies fail closed")
        check(LyricsSelection.select([candidate("LRCLIB", text: lines(count: 4)), candidate("QQ", text: lines(10, count: 4))], context: netease).winner == nil, "short four-line shifted timeline fails closed")
        check(LyricsSelection.select([candidate("LRCMux", platform: "lrclib")], context: netease).winner == nil, "resolver metadata alone cannot establish lyric source compatibility")
        let muxSupported = LyricsSelection.select([candidate("LRCMux", platform: "lrclib"), candidate("LRCLIB", platform: "lrclib")], context: netease)
        check(muxSupported.winner != nil && muxSupported.rejected["LRCMux"] != "resolver_metadata_unverified", "direct source metadata can corroborate resolver timeline without elevating exact identity")
        let sharedIntro = lines(count: 5)
        let bodyA = sharedIntro + (5..<40).map { LyricLine(time: Double($0) * 4.5, text: "Distinct A verse \($0)") }
        let bodyB = sharedIntro + (5..<40).map { LyricLine(time: Double($0) * 4.5, text: "Distinct B verse \($0)") }
        check(LyricsSelection.select([candidate("LRCLIB", text: bodyA), candidate("QQ", text: bodyB)], context: netease).winner == nil, "shared intro cannot establish agreement for differing majority body")
        check(LyricsSelection.select([exact, candidate("NetEase", platform: "netease", id: "actual-catalog", text: lines(14))], context: netease).winner == nil, "conflicting payloads for the same proven catalog identity fail closed")
        let wordLines = lines().map { LyricLine(time: $0.time, text: $0.text, endTime: $0.time + 3, segments: [LyricSegment(time: $0.time, endTime: $0.time + 2, text: $0.text)]) }
        check(LyricsSelection.select([candidate("NetEase", platform: "netease"), candidate("QQ", platform: "qq", text: wordLines)], context: netease).winner?.provider == "NetEase", "same-platform affinity precedes fidelity at equal recording confidence")
        let wrongWord = candidate("Kugou", platform: "kugou", text: wordLines, title: "Song (Live)")
        check(wrongWord.document.timingFidelity == .word && LyricsSelection.select([wrongWord, exact], context: netease).winner == exact, "measured word fidelity cannot override wrong recording version")
        let credits = [LyricLine(time: 0, text: "作词：Fixture")] + lines(0.22)
        check(!LyricsSelection.timelinesConflict(candidate("NetEase"), candidate("QQ", text: credits)), "credits do not create first-timestamp conflict")
        check(LyricsSelection.select([candidate("NetEase"), candidate("QQ", text: credits)], context: netease).winner != nil, "compatible vocal anchors remain selectable")
        check(LyricsSelection.select([candidate("Word", text: lines(), title: "Song (Live)")], context: netease).winner == nil, "fidelity never overrides version mismatch")
        check(LyricsSelection.select([candidate("LRCLIB", album: "Album (Remaster)")], context: netease).winner == nil, "album master hint mismatch rejected")
        check(LyricsSelection.select([candidate("NetEase", duration: 206)], context: netease).winner == nil, "six-second generic duration delta rejected")
        check(LyricsSelection.select([candidate("NetEase", duration: nil)], context: netease).winner == nil, "missing source duration remains unknown")
        let spotify = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "spotify:track:SP", isrc: nil)
        let spotifyExact = candidate("Spotify", platform: "spotify", id: "SP")
        check(LyricsSelection.select([generic, spotifyExact], context: spotify).winner == spotifyExact, "Spotify URI and source ID share catalog namespace")
        check(LyricsSelection.select([candidate("Spotify", platform: "spotify", id: "other")], context: spotify).winner == nil, "same-platform source ID mismatch rejected")
        check(LyricsSelection.select([candidate("Kugou", platform: "kugou")], context: spotify).winner == nil, "unverified single cross-platform Spotify timeline rejected")
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), candidate("LRCMux", platform: "lrclib")], context: spotify).winner == nil, "resolver alias is not independent consensus")
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), candidate("QQ", platform: "qq")], context: spotify).winner != nil, "independent agreeing timelines can establish metadata compatibility")
        let isrcContext = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "SP", isrc: "USAAA2600001")
        check(LyricsSelection.identityTier(candidate("LRCMux", isrc: "USAAA2600001"), context: isrcContext) == 4, "resolver ISRC cannot claim timeline identity")
        check(LyricsSelection.select([candidate("QQ", platform: "qq", isrc: "USAAA2600001")], context: isrcContext).tier == "B exact ISRC", "independently sourced matching ISRC receives Tier B")
        check(LyricsSelection.select([candidate("QQ", isrc: "USAAA2600002")], context: isrcContext).winner == nil, "known ISRC mismatch rejected")
        let fullVocal = (0..<18).map { LyricLine(time: 10 + Double($0) * 10, text: "Vocal phrase \($0)") }
        let strongSingle = candidate("NetEase", platform: "netease", id: "source-recording", text: fullVocal, duration: 201)
        check(LyricsSelection.select([strongSingle], context: spotify).winner == strongSingle, "strong album and full timeline recover a direct Spotify cross-platform candidate")
        check(LyricsSelection.select([candidate("NetEase", platform: "netease", id: "source-recording", text: fullVocal, duration: 207, album: nil)], context: spotify).winner == nil, "weak seven-second unknown-album candidate stays rejected")
        check(LyricsSelection.select([strongSingle, spotifyExact], context: spotify).winner == spotifyExact, "exact platform identity beats strong metadata recovery")
        let isrcCandidate = candidate("QQ", platform: "qq", isrc: "USAAA2600001")
        check(LyricsSelection.select([strongSingle, isrcCandidate], context: isrcContext).winner == isrcCandidate, "independent exact ISRC beats strong metadata recovery")
        check(LyricsSelection.select([strongSingle, candidate("QQ", platform: "qq", text: fullVocal.map { LyricLine(time: $0.time + 14, text: $0.text) })], context: spotify).winner == nil, "strong metadata never overrides equal-confidence timeline conflict")
        let unboundMux = candidate("LRCMux", platform: "kugou", text: lines(prefix: "Unrelated resolver body"))
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), unboundMux], context: netease).winner?.provider == "LRCLIB", "unverified resolver cannot poison a directly bound candidate")
        let wrongAlbum = candidate("QQ", platform: "qq", text: lines(14), album: "Other recording album")
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), wrongAlbum], context: netease).winner?.provider == "LRCLIB", "known generic album mismatch is rejected before timeline arbitration")
        let unknownAlbum = candidate("Kugou", platform: "kugou", text: lines(prefix: "Unknown recording body"), album: nil)
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), unknownAlbum], context: netease).winner?.provider == "LRCLIB", "unconfirmed unknown-album identity cannot veto strong album evidence")
        check(LyricsSelection.select([unknownAlbum], context: netease).winner == nil, "unknown album alone cannot establish strong metadata identity")
        let splitBody = (0..<8).flatMap { i in [LyricLine(time: 10 + Double(i) * 5, text: "Vocal"), LyricLine(time: 11 + Double(i) * 5, text: "phrase \(i)")] }
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), candidate("QQ", platform: "qq", text: splitBody)], context: netease).winner != nil, "identical complete vocal body with matching boundaries survives different line breaks")
        let creditedBody = lines() + [LyricLine(time: 195, text: "录音师：Fixture"), LyricLine(time: 196, text: "古典吉他：Fixture"), LyricLine(time: 197, text: "插画：Fixture")]
        let creditedSplit = [LyricLine(time: 0, text: "Song - Artist")] + splitBody
        check(LyricsSelection.select([candidate("NetEase", platform: "netease", text: creditedBody), candidate("QQ", platform: "qq", text: creditedSplit)], context: netease).winner != nil, "structured recording credits and title headers cannot create false vocal body conflict")
        let splitShifted = splitBody.map { LyricLine(time: $0.time + 14, text: $0.text) }
        check(LyricsSelection.select([candidate("LRCLIB", platform: "lrclib"), candidate("QQ", platform: "qq", text: splitShifted)], context: netease).winner == nil, "segmentation recovery still rejects a shifted complete body")
        let raced = await LyricsClient.collect([
            { _ in try await Task.sleep(for: .milliseconds(50)); return generic },
            { _ in try await Task.sleep(for: .milliseconds(150)); return exact }
        ], names: ["LRCLIB", "NetEaseExactID (Preview)"], for: track, window: 1)
        check(raced.candidates.count == 2 && LyricsSelection.select(raced.candidates, context: netease).winner?.provider == exact.provider, "50ms first-response trap loses to 150ms verified exact")
        let qq = candidate("QQ")
        let began = Date()
        let bounded = await LyricsClient.collect([
            { _ in try await Task.sleep(for: .seconds(5)); return generic },
            { _ in return qq }
        ], names: ["slow", "QQ"], for: track, window: 0.05)
        check(Date().timeIntervalSince(began) < 0.5 && bounded.statuses["slow"] == "deadline", "collection cancels cooperative source at deadline")
        check(bounded.candidates.count == 1, "late candidate excluded from selection")
        let singleRelease = LyricsSelectionContext(track: SpotifyTrack(name: "Song", artist: "Artist", album: "Album - Single", duration: 200), playerSource: "Spotify", nativeTrackID: "SP", isrc: nil)
        check(LyricsSelection.select([strongSingle], context: singleRelease).winner == strongSingle, "Single release-type suffix does not change normalized album identity")
        let traditionalAlbum = LyricsSelectionContext(track: SpotifyTrack(name: "Song", artist: "Artist", album: "遠方", duration: 200), playerSource: "NetEase Cloud Music", nativeTrackID: nil, isrc: nil)
        check(LyricsSelection.select([candidate("NetEase", platform: "netease", album: "远方")], context: traditionalAlbum).winner != nil, "traditional and simplified album names keep the same metadata identity")
        let formattedISRC = candidate("QQ", platform: "qq", isrc: " us-aaa-26-00001 ")
        check(LyricsSelection.select([formattedISRC], context: isrcContext).tier == "B exact ISRC", "documented ISRC formatting preserves independently sourced Tier B identity")
        let formattedContext = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "SP", isrc: " us-aaa-26-00001 ")
        check(formattedContext.cacheKey == isrcContext.cacheKey, "canonical ISRC formatting shares only the same player and native cache scope")
        let invalidISRC = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "SP", isrc: "invalid")
        check(LyricsSelection.identityTier(candidate("QQ", isrc: "invalid"), context: invalidISRC) == 3, "matching malformed strings cannot fabricate an ISRC identity tier")
        let deniedClient = LyricsClient(candidateSources: [{ _ in unknownAlbum }], names: ["Kugou"])
        _ = try await deniedClient.syncedLyrics(for: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR")
        check(deniedClient.selectionDiagnostics.contains("No Lyrics Reason: identity_ambiguous"), "No Lyrics diagnostics distinguish insufficient identity")
        check(deniedClient.selectionDiagnostics.contains("Top candidate: Kugou"), "No Lyrics diagnostics retain the rejected top source")
        let primaryStart = Date()
        let primary = await LyricsClient.collect([
            { _ in try await Task.sleep(for: .milliseconds(30)); return nil },
            { _ in try await Task.sleep(for: .milliseconds(80)); return exact },
            { _ in try await Task.sleep(for: .seconds(2)); return generic }
        ], names: ["NetEase", "NetEaseExactID (Preview)", "LRCLIB"], for: track, window: 3, context: netease)
        check(Date().timeIntervalSince(primaryStart) < 0.5 && LyricsSelection.select(primary.candidates, context: netease).winner?.provider == exact.provider, "verified NetEase primary skips unrelated slow providers after direct source completes")
        check(primary.statuses["LRCLIB"] == "skipped_after_verified_exact", "staged exact cancellation is explicit in diagnostics")
        let primaryDisagreement = candidate("NetEase", platform: "netease", id: "actual-catalog", text: lines(14))
        let primaryConflict = await LyricsClient.collect([
            { _ in return primaryDisagreement },
            { _ in return exact }
        ], names: ["NetEase", "NetEaseExactID (Preview)"], for: track, window: 1, context: netease)
        check(LyricsSelection.select(primaryConflict.candidates, context: netease).winner == nil, "staged primary still refuses disagreeing payloads for the same proven ID")
        let client = LyricsClient(candidateSources: [{ _ in generic }], names: ["LRCLIB"])
        let recovered = try await client.syncedLyrics(for: track, exactSource: { _ in
            try await Task.sleep(for: .milliseconds(150)); return exact
        }, playerSource: "NetEase Cloud Music", nativeTrackID: "MR-generation")
        check(recovered == exact.document.normalizedLines && client.selectedProvider == exact.provider, "exact source is concurrent first-class even with generic HIT")
        check(client.selectedDocument?.metadata.platformTrackID == "actual-catalog", "selected document retains source catalog ID instead of MediaRemote generation")
        let next = try await client.syncedLyrics(for: track, exactSource: { _ in nil }, playerSource: "NetEase Cloud Music", nativeTrackID: "MR-generation")
        check(next != recovered, "live exact result never cached as generic evidence")
        check(spotify.cacheKey != netease.cacheKey, "cross-player metadata cache separated")
        check(spotify.cacheKey != isrcContext.cacheKey, "ISRC participates in cache scope")
        let alternate = LyricsSelectionContext(track: track, playerSource: "Spotify", nativeTrackID: "spotify:track:OTHER", isrc: nil)
        check(spotify.cacheKey != alternate.cacheKey, "same-player native identity separated")
        let calls = SelectionCalls()
        let cachedClient = LyricsClient(candidateSources: [{ _ in await calls.record(); return generic }], names: ["LRCLIB"])
        _ = try await cachedClient.syncedLyrics(for: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR1")
        _ = try await cachedClient.syncedLyrics(for: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR1")
        check(await calls.count == 1, "actual candidate cache reuses only identical context")
        _ = try await cachedClient.syncedLyrics(for: track, playerSource: "Apple Music", nativeTrackID: "MR1")
        check(await calls.count == 2, "actual candidate cache separates players with same metadata and ID string")
        _ = try await cachedClient.syncedLyrics(for: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR2")
        check(await calls.count == 3, "actual candidate cache separates native IDs")
        _ = try await cachedClient.syncedLyrics(for: track, playerSource: "NetEase Cloud Music", nativeTrackID: "MR2", isrc: "ISRC1")
        check(await calls.count == 4, "actual candidate cache separates ISRC")
        _ = try await cachedClient.syncedLyrics(for: track, bypassCache: true, playerSource: "NetEase Cloud Music", nativeTrackID: "MR2", isrc: "ISRC1")
        check(await calls.count == 5, "refresh recollects evidence")
        check(cachedClient.selectedDocument?.metadata.platformTrackID == "catalog", "cache preserves actual source ID")
        let remaster = SpotifyTrack(name: "Song - 2011 Remaster", artist: "Artist", album: "Album", duration: 200)
        let remasterContext = LyricsSelectionContext(track: remaster, playerSource: "NetEase Cloud Music", nativeTrackID: nil, isrc: nil)
        check(LyricsSelection.select([candidate("NetEase", title: "Song (Remastered 2011)")], context: remasterContext).winner != nil, "equivalent remaster labels stay compatible")
        check(LyricsSelection.select([candidate("NetEase", title: "Song (Remastered 2023)")], context: remasterContext).winner == nil, "different remaster years rejected")
        let secondRecording = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 210)
        let secondContext = LyricsSelectionContext(track: secondRecording, playerSource: "NetEase Cloud Music", nativeTrackID: "MR-other", isrc: nil)
        let secondExact = candidate("NetEaseExactID (Preview)", platform: "netease", id: "second-catalog", text: lines(5), duration: 210, verified: true)
        check(LyricsSelection.select([spotifyExact, secondExact], context: secondContext).winner == secondExact, "cross-platform different recording chooses its verified timeline")
        print("Lyrics selection: \(checks - failures)/\(checks) PASS")
        if failures > 0 { exit(1) }
    }
}
