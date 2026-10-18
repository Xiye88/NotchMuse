import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) { }
    static func lyrics(_ text: String) { }
}

@main struct SpotifyIdentityBridgeTests {
    @MainActor static func main() async throws {
        let uri = "spotify:track:0123456789012345678901"
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Player Album", duration: 200)
        func identity(_ id: String = uri, duration: Double = 200, isrc: String? = "USZZZ2600001") -> SpotifyCanonicalIdentity {
            SpotifyCanonicalIdentity(nativeTrackID: id, title: "Song", artists: ["Artist"], album: "Canonical Album", duration: duration, isrc: isrc, identitySource: "official Spotify Get Track response")
        }
        var checks = 0
        func check(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        let publicIdentity = SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song", artists: ["Artist", "Guest"], album: "", duration: 200, isrc: nil, identitySource: "Spotify public Embed URI response")
        var publicTrack: SpotifyTrack?
        do { publicTrack = try publicIdentity.validatedTrack(for: track, expectedURI: uri) } catch { }
        check(publicTrack?.artist == "Artist, Guest" && publicTrack?.album == track.album, "URI-bound public collaborators must enrich native identity without credentials")
        for invalid in [
            SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song (Live)", artists: ["Artist"], album: "", duration: 200, isrc: nil, identitySource: publicIdentity.identitySource),
            SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song", artists: ["Artist"], album: "Injected Album", duration: 200, isrc: nil, identitySource: publicIdentity.identitySource),
            SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song", artists: ["Artist"], album: "", duration: 200, isrc: "USZZZ2600001", identitySource: publicIdentity.identitySource),
            SpotifyCanonicalIdentity(nativeTrackID: uri, title: "Song", artists: ["Artist"], album: "", duration: 203, isrc: nil, identitySource: publicIdentity.identitySource)
        ] {
            do { _ = try invalid.validatedTrack(for: track, expectedURI: uri); preconditionFailure("unproven public identity accepted") }
            catch { checks += 1 }
        }
        func publicHTML(type: String = "track", id: String = String(uri.suffix(22)), artistURI: String = "spotify:artist:1123456789012345678901") throws -> Data {
            let entity: [String: Any] = ["type": type, "id": id, "uri": uri, "name": "Song", "duration": 200000,
                "artists": [["name": "Artist", "uri": artistURI]], "isrc": "UNTRUSTED", "album": "UNTRUSTED"]
            let json = try JSONSerialization.data(withJSONObject: ["props": ["pageProps": ["state": ["data": ["entity": entity]]]]])
            return Data(("<script id=\"__NEXT_DATA__\" type=\"application/json\">" + String(decoding: json, as: UTF8.self) + "</script>").utf8)
        }
        let decoded = try SpotifyIdentityResolver.parsePublicHTML(publicHTML(), expectedURI: uri)
        check(decoded.isrc == nil && decoded.album.isEmpty && decoded.duration == 200, "public parser ignores unbound ISRC/album fields and converts milliseconds")
        for html in [try publicHTML(type: "episode"), try publicHTML(id: "other"), try publicHTML(artistURI: "invalid"), Data("<html>No metadata</html>".utf8)] {
            do { _ = try SpotifyIdentityResolver.parsePublicHTML(html, expectedURI: uri); preconditionFailure("unbound public HTML accepted") }
            catch { checks += 1 }
        }
        let traditional = SpotifyTrack(name: "我愛你 是為了開始愛你", artist: "梁詠琪", album: "Album", duration: 200)
        check(TrackMatcher.identityRejectReason(traditional, title: "我爱你 是为了开始爱你", artist: "梁咏琪", album: "Album") == nil, "reversible Chinese script spelling preserves title and artist identity")
        check(TrackMatcher.identityRejectReason(traditional, title: "我爱你 是为了开始爱你 (Live)", artist: "梁咏琪", album: "Album") == "version_mismatch", "script equivalence never drops Live identity")
        check(TrackMatcher.parsedTitle("髮").name != TrackMatcher.parsedTitle("發").name, "non-reversible script homographs remain distinct")
        check(try identity().validatedTrack(for: track, expectedURI: uri).album == "Canonical Album", "official native ID supplies canonical album")
        for invalid in [identity("spotify:track:1123456789012345678901"), identity(duration: 210), identity(isrc: "hint")] {
            do { _ = try invalid.validatedTrack(for: track, expectedURI: uri); preconditionFailure("bad identity accepted") }
            catch { checks += 1 }
        }
        let lines = (0..<10).map { LyricLine(time: Double($0) * 18 + 10, text: "synthetic vocal line \($0)") }
        @Sendable func candidate(_ sourceISRC: String?, album: String = "Canonical Album", shifted: Bool = false) -> LyricsCandidate {
            LyricsCandidate(document: TimedLyricDocument(lines: shifted ? lines.map { LyricLine(time: $0.time + 8, text: $0.text) } : lines), provider: shifted ? "Other" : "Test", sourcePlatform: "qq", sourceTrackID: shifted ? "2" : "1", sourceTitle: "Song", sourceArtist: "Artist", sourceAlbum: album, sourceDuration: 200, sourceISRC: sourceISRC, matcherScore: 100)
        }
        let official = identity()
        let client = LyricsClient(candidateSources: [{ _ in candidate("USZZZ2600001") }], names: ["Test"], identityResolver: { _ in official })
        let result = try await client.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri)
        check(!result.isEmpty && client.selectionDiagnostics.contains("B exact ISRC"), "independent candidate ISRC joins official canonical ISRC")
        let withoutProof = LyricsClient(candidateSources: [{ _ in candidate(nil) }], names: ["Test"], identityResolver: { _ in official })
        _ = try await withoutProof.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri)
        check(withoutProof.selectedCandidate?.sourceISRC == nil && !withoutProof.selectionDiagnostics.contains("B exact ISRC"), "canonical query never becomes source proof")
        let mismatch = LyricsClient(candidateSources: [{ _ in candidate("USZZZ2600002") }], names: ["Test"], identityResolver: { _ in official })
        check(try await mismatch.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri).isEmpty, "mismatched source ISRC refuses lyrics")
        let context = LyricsSelectionContext(track: try official.validatedTrack(for: track, expectedURI: uri), playerSource: "Spotify", nativeTrackID: uri, isrc: official.isrc)
        check(LyricsSelection.select([candidate("USZZZ2600001"), candidate("USZZZ2600001", shifted: true)], context: context).winner == nil, "same ISRC does not bypass timeline conflict")
        let netease = LyricsClient(candidateSources: [{ _ in candidate(nil, album: "Player Album") }], names: ["Test"], identityResolver: { _ in preconditionFailure("Spotify bridge called for NetEase") })
        check(try await !netease.syncedLyrics(for: track, playerSource: "NetEaseMusic", nativeTrackID: "28285910").isEmpty, "non-Spotify path remains unchanged")
        let unavailable = LyricsClient(candidateSources: [{ _ in candidate(nil, album: "Player Album") }], names: ["Test"], identityResolver: { _ in throw URLError(.userAuthenticationRequired) })
        check(try await !unavailable.syncedLyrics(for: track, playerSource: "Spotify", nativeTrackID: uri).isEmpty, "OAuth failure retains strict original metadata fallback")
        print("PASS: \(checks) Spotify bridge checks; synthetic tests are not real recovery evidence")
    }
}
