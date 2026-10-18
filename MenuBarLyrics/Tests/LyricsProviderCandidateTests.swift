import Foundation
import LyricsCore

// Standalone source-boundary tests; no network or player access.
enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyricsDiagnostic(_ text: String) { }
    static func lyrics(_ text: String) { }
}

@main struct LyricsProviderCandidateTests {
    static func main() throws {
        var checks = 0
        func check(_ passed: Bool, _ message: String) { precondition(passed, message); checks += 1 }
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Request Album", duration: 200, nativeTrackID: "spotify:track:4uLU6hMCjMI75M1A2tKUQC")
        let line = LyricLine(time: 10, text: "fixture")
        let lrclibData = Data(#"[{"id":42,"trackName":"Song","artistName":"Artist","albumName":"Actual Album","duration":201,"syncedLyrics":"[offset:500]\n[00:10.00]fixture"}]"#.utf8)
        let lrclib = try LRCLIBLyricsSource().parseCandidate(lrclibData, for: track)!
        check(lrclib.sourceTrackID == "42" && lrclib.sourcePlatform == "lrclib", "LRCLIB preserves catalog namespace")
        check(lrclib.sourceAlbum == "Actual Album" && lrclib.sourceDuration == 201, "LRCLIB preserves selected album/duration")
        check(lrclib.document.metadata.lyricOffset == 0.5 && lrclib.document.normalizedLines[0].time == 9.5, "LRCLIB offset normalized once")
        check(try LRCLIBLyricsSource().parse(lrclibData, for: track) == lrclib.document.normalizedLines, "LRCLIB legacy parser compatibility")
        check(TrackMatcher.artistGroupKey("Artist feat. Guest", expectedArtists: ["Artist, Guest"]) == Set(["artist", "guest"]), "feat. syntax shares the canonical artist group")
        check(TrackMatcher.artistGroupKey("Artist and Guest", expectedArtists: ["Artist, Guest"]) == Set(["artist", "guest"]), "and syntax is accepted only with matching expected artists")
        check(TrackMatcher.artistGroupKey("Artist and Guest", expectedArtists: ["Artist"]) == Set(["artistandguest"]), "and syntax does not split without sufficient context")
        check(TrackMatcher.artistGroupKey("The Band", expectedArtists: ["The Band"]) == Set(["theband"]), "natural-language artist names remain intact")
        let collaborators = SpotifyTrack(name: "Song", artist: "Artist, Guest", album: "Request Album", duration: 200)
        let andCandidateData = Data(#"[{"id":99,"trackName":"Song","artistName":"Artist and Guest","albumName":"Request Album","duration":200,"syncedLyrics":"[00:10.00]fixture"}]"#.utf8)
        check(try LRCLIBLyricsSource().parseCandidate(andCandidateData, for: collaborators)?.sourceTrackID == "99", "context-aware and artist candidate remains selectable")
        func duplicatePayload(_ secondLRC: String, _ secondDuration: Double = 200) throws -> Data {
            try JSONSerialization.data(withJSONObject: [
                ["id": 1, "trackName": "Song", "artistName": "Artist", "albumName": "Original", "duration": 200, "syncedLyrics": "[00:10.00]fixture"],
                ["id": 2, "trackName": "song", "artistName": "ARTIST", "albumName": "Alternate", "duration": secondDuration, "syncedLyrics": secondLRC]
            ])
        }
        check(try LRCLIBLyricsSource().parseCandidate(duplicatePayload("[00:10.00]fixture"), for: track) != nil, "identical duplicate uploads do not create ambiguity")
        check(try LRCLIBLyricsSource().parseCandidate(duplicatePayload("[00:20.00]fixture"), for: track) == nil, "same metadata conflicting vocal start rejects before dedup")
        check(try LRCLIBLyricsSource().parseCandidate(duplicatePayload("[00:10.00]different words"), for: track) == nil, "same metadata different lyric text rejects before dedup")
        check(try LRCLIBLyricsSource().parseCandidate(duplicatePayload("[offset:1000]\n[00:10.00]fixture"), for: track) == nil, "different effective offset is conflicting timeline")
        check(try LRCLIBLyricsSource().parseCandidate(duplicatePayload("[00:10.00]fixture", 202), for: track) == nil, "competing recording duration not silently deduplicated")
        let netease = NetEaseLyricsSource()
        let search = Data(#"{"result":{"songs":[{"id":456,"name":"Song","artists":[{"name":"Artist"}],"duration":200500,"album":{"name":"Catalog Album"}}]}}"#.utf8)
        let song = netease.selectedSong(try netease.parseSearch(search), for: track)!
        let neteaseCandidate = netease.makeCandidate(song: song, lines: [line], for: track)!
        check(neteaseCandidate.sourceTrackID == "456" && neteaseCandidate.sourcePlatform == "netease", "NetEase preserves actual selected ID")
        check(neteaseCandidate.sourceAlbum == "Catalog Album" && neteaseCandidate.sourceDuration == 200.5, "NetEase milliseconds converted exactly")
        check(neteaseCandidate.sourceISRC == nil, "metadata match does not manufacture ISRC")
        let releases = Data(#"{"result":{"songs":[{"id":1,"name":"Song","artists":[{"name":"Artist"}],"duration":200000,"album":{"name":"Single"}},{"id":2,"name":"Song","artists":[{"name":"Artist"}],"duration":200000,"album":{"name":"Request Album"}}]}}"#.utf8)
        let releaseSongs = try netease.parseSearch(releases)
        check(releaseSongs.count == 2 && netease.selectedSong(releaseSongs, for: track)?.id == 2, "different albums survive dedup; strict requested album ranked first")
        let conflictReleases = Data(#"[{"id":1,"trackName":"Song","artistName":"Artist","albumName":"Single","duration":200,"syncedLyrics":"[00:30.00]other version"},{"id":2,"trackName":"Song","artistName":"Artist","albumName":"Request Album","duration":200,"syncedLyrics":"[00:10.00]fixture"}]"#.utf8)
        check(try LRCLIBLyricsSource().parseCandidate(conflictReleases, for: track)?.sourceTrackID == "2", "ineligible release cannot hide the strict album-bound upload")
        let sameAlbumConflict = String(decoding: conflictReleases, as: UTF8.self).replacingOccurrences(of: "Single", with: "Request Album")
        check(try LRCLIBLyricsSource().parseCandidate(Data(sameAlbumConflict.utf8), for: track) == nil, "same requested album with conflicting lyrics still refuses")
        let mux = LRCMuxLyricsSource()
        func muxData(_ source: String, _ url: String) -> Data {
            Data("""
            {"track":{"title":"Song","artist":"Artist","album":"Resolved Album","duration":200,"isrc":"USAAA2600001"},"meta":{"source":{"id":"\(source)","name":"Fixture","url":"\(url)"},"level":"line"},"lines":[{"text":"fixture","start":10000,"end":12000}]}
            """.utf8)
        }
        let muxCandidate = try mux.parseCandidate(muxData("netease", "https://music.163.com/#/song?id=987"), for: track)!
        check(muxCandidate.sourceTrackID == "987" && muxCandidate.sourcePlatform == "netease", "LRCMux exposes verified-host source ID")
        check(muxCandidate.sourceAlbum == "Resolved Album" && muxCandidate.sourceISRC == "USAAA2600001", "LRCMux preserves resolver metadata separately")
        check(muxCandidate.document.timingFidelity == .estimated, "LRCMux synthetic line ends remain estimated")
        check(try mux.parseCandidate(muxData("netease", "https://example.com/song?id=987"), for: track)!.sourceTrackID == nil, "LRCMux rejects foreign host identity")
        check(try mux.parseCandidate(muxData("kugou", "https://kugou.com"), for: track)!.sourceTrackID == nil, "provider homepage does not identify recording")
        let qq = QQMusicLyricsSource()
        let qqData = Data(#"{"req_1":{"data":{"body":{"song":{"list":[{"mid":"source-mid","title":"Song","singer":[{"name":"Artist"}],"interval":201,"album":{"name":"QQ Album"}}]}}}}}"#.utf8)
        let qqSong = try qq.matchingSong(in: qqData, for: track)!
        let qqCandidate = qq.makeCandidate(song: qqSong, lines: [line], for: track)!
        check(qqCandidate.sourceTrackID == "source-mid" && qqCandidate.sourcePlatform == "qq", "QQ actual MID retained")
        check(qqCandidate.sourceAlbum == "QQ Album" && qqCandidate.sourceDuration == 201, "QQ selected metadata retained")
        check(try qq.matchingSongMID(in: qqData, for: track) == qqCandidate.sourceTrackID, "QQ old MID parser compatibility")
        let qqReleases = Data(#"{"req_1":{"data":{"body":{"song":{"list":[{"mid":"single","title":"Song","singer":[{"name":"Artist"}],"interval":200,"album":{"name":"Single"}},{"mid":"bound","title":"Song","singer":[{"name":"Artist"}],"interval":200,"album":{"name":"Request Album"}}]}}}}}"#.utf8)
        check(try qq.matchingSongMID(in: qqReleases, for: track) == "bound", "QQ applies the strict album gate before ambiguity ranking")
        let kugou = KugouLyricsSource()
        let kugouCandidate = kugou.makeCandidate(song: .init(hash: "recording-hash", title: "Song", artist: "Artist", duration: 200), lyrics: .init(id: "lyric-download-id", accessKey: "fixture", title: "Song", artist: "Artist", durationMs: 200750), lines: [line], for: track)!
        check(kugouCandidate.sourceTrackID == "recording-hash", "Kugou recording hash distinguishes lyric download ID")
        check(kugouCandidate.sourceDuration == 200.75 && kugouCandidate.sourcePlatform == "kugou", "Kugou lyric metadata retained")
        let soda = SodaMusicLyricsSource(deviceID: "fixture", installID: "fixture")
        let sodaData = Data(#"{"track":{"id":"soda-recording","name":"Song","artists":[{"name":"Artist"}],"duration":200250,"album":{"name":"Soda Album"}},"lyric":{"type":"lrc","content":"[00:10.00]fixture"}}"#.utf8)
        let sodaCandidate = try soda.parseCandidate(sodaData, for: track, expectedTrackID: "soda-recording")!
        check(sodaCandidate.sourceTrackID == "soda-recording" && sodaCandidate.sourcePlatform == "soda", "Soda details preserve identity")
        check(sodaCandidate.sourceAlbum == "Soda Album" && sodaCandidate.sourceDuration == 200.25, "Soda details preserve album/duration")
        check(try soda.parseCandidate(sodaData, for: track, expectedTrackID: "different-id") == nil, "Soda detail ID disagreement rejected")
        check(try soda.parseDetail(sodaData, for: track) == sodaCandidate.document.normalizedLines, "Soda legacy parser compatibility")
        for candidate in [lrclib, neteaseCandidate, muxCandidate, qqCandidate, kugouCandidate, sodaCandidate] {
            check(candidate.sourceTitle == "Song" && candidate.sourceArtist == "Artist", "selected title/artist retained")
            check(candidate.sourceTrackID != track.nativeTrackID, "request native identity never fabricated for generic provider")
            check(candidate.matcherScore != nil, "actual matcher score preserved")
        }
        print("PASS \(checks) provider candidate checks")
    }
}
