import Foundation
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) {}
    static func metadata(_ text: String) -> String { text }
    static func lyrics(_ text: String) {}
    static func lyricsDiagnostic(_ text: @autoclosure () -> String) {}
}
actor TranslationCalls {
    var count = 0
    func next() -> Int { count += 1; return count }
}
@main enum BilingualLyricsTests {
    @MainActor static func main() async throws {
        var checks = 0, failures = 0
        func check(_ ok: Bool, _ message: String) { checks += 1; if !ok { failures += 1; print("FAIL: \(message)") } }
        let source = NetEaseLyricsSource()
        func parse(_ original: String = "[00:10]Hello\n[00:20]World\n[00:30]Again", translation: Any? = nil, yrc: String? = nil) throws -> [LyricLine] {
            var payload: [String:Any] = ["code":200,"lrc":["lyric":original]]
            if let translation { payload["tlyric"] = translation }
            if let yrc { payload["yrc"] = ["lyric":yrc] }
            return try source.parseLyrics(JSONSerialization.data(withJSONObject:payload)) ?? []
        }
        let plain = try parse()
        check(plain.count == 3 && plain.allSatisfy { $0.translation == nil }, "missing translation preserves original")
        for malformed in [NSNull(), 42, "bad", ["lyric":42], ["lyric":NSNull()]] as [Any] {
            check(try parse(translation:malformed) == plain, "malformed translation schema cannot lose original")
        }
        let aligned = try parse(translation:["lyric":"[00:01]Unrelated\n[00:10]你好\n[00:30]再来"])
        check(aligned.map(\.translation) == ["你好",nil,"再来"], "different line counts align by time instead of shifting indexes")
        let near = try parse(translation:["lyric":"[00:10.30]近邻\n[00:20.46]太远"])
        check(near.map(\.translation) == ["近邻",nil,nil], "bounded near timestamps attach but 460ms does not")
        let offset = try parse("[offset:500]\n[00:10]Hello\n[00:20]World", translation:["lyric":"[offset:1000]\n[00:10.50]你好\n[00:20.50]世界"])
        check(offset.map(\.time) == [9.5,19.5] && offset.map(\.translation) == ["你好","世界"], "both source offsets normalized once before matching")
        let yrc = "[offset:500]\n[10000,2000](10000,1000,0)Hel(11000,1000,0)lo\n[20000,2000](20000,2000,0)World"
        let rich = try parse("[00:01]Wrong LRC baseline", translation:["lyric":"[00:09.50]你好\n[00:19.50]世界"], yrc:yrc)
        check(rich.map(\.time) == [9.5,19.5] && rich.map(\.translation) == ["你好","世界"], "YRC normalized timeline takes priority over fallback LRC")
        check(rich[0].text == "Hello" && rich[0].segments.count == 2 && rich[0].endTime == 11.5, "attaching translation does not change text, real words or ends")
        check(try parse(translation:["lyric":"[00:10]甲\n[00:10]乙"]).allSatisfy { $0.translation == nil }, "duplicate translation timestamps remain ambiguous")
        let repeated = try parse("[00:10]A\n[00:10]B", translation:["lyric":"[00:10]译文"])
        check(repeated.allSatisfy { $0.translation == nil }, "one translation cannot attach to duplicate original starts")
        let crowded = try parse("[00:10]A\n[00:10.40]B", translation:["lyric":"[00:10.20]译文"])
        check(crowded.allSatisfy { $0.translation == nil }, "nearby ambiguous originals fail closed")
        check(try parse(translation:["lyric":"[00:10]  \n[00:20]世界"]).map(\.translation) == [nil,"世界",nil], "empty translation remains nil without shifting remaining entries")
        check(try parse(translation:["lyric":"untimed translation"]) == plain, "untimed translation never receives invented timing")
        let shifted = rich[0].shifted(by:2)
        check(shifted.translation == "你好" && shifted.time == 11.5 && shifted.segments[0].time == 11.5, "shift preserves translation while shifting only real timing")
        let normalized = TimedLyricDocument(lines:rich,metadata:LyricsMetadata(lyricOffset:1)).normalizedLines
        check(normalized[0].translation == "你好" && normalized[0].time == 8.5, "document normalization preserves translation")
        check(LyricLine(time:1,text:"A",translation:" \n").translation == nil, "whitespace-only translation is absent")
        let track = SpotifyTrack(name:"Song",artist:"Artist",album:"Album",duration:200)
        let calls = TranslationCalls()
        let client = LyricsClient(sources:[{ _ in
            let n = await calls.next()
            return [LyricLine(time:10,text:"Original",translation:"Translation \(n)")]
        }])
        let first = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"A")
        let cached = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"A")
        check(first == cached && cached[0].translation == "Translation 1", "cache retains same-recording translation")
        let second = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"B")
        check(second[0].translation == "Translation 2", "different native identity does not reuse previous translation")
        let otherPlayer = try await client.syncedLyrics(for:track,playerSource:"NetEase Music",nativeTrackID:"B")
        check(otherPlayer[0].translation == "Translation 3", "different player identity does not reuse previous translation")
        let candidate = source.makeCandidate(song:Song(id:1,name:"Song",artists:[Artist(name:"Artist")],duration:200000,album:NetEaseAlbum(name:"Album")),lines:rich,for:track)
        check(candidate?.document.lines[0].translation == "你好", "source candidate carries translation without a parallel cache")
        fflush(stdout)
        precondition(failures == 0,"\(failures) bilingual failures")
        print("PASS: \(checks) bilingual data checks; fixed fixtures only")
    }
}
