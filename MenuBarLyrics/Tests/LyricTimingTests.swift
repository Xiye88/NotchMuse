import Foundation
import AppKit
import LyricsCore

enum DebugLog {
    static func spotify(_ text: String) { }
    static func metadata(_ text: String) -> String { text }
    static func lyrics(_ text: String) { }
    static func lyricsDiagnostic(_ text: @autoclosure () -> String) { }
}
actor Calls {
    var count = 0
    func next() -> Int { count += 1; return count }
}
@main struct TimingTests {
    static var checks = 0
    static func check(_ condition: Bool, _ label: String) { precondition(condition, label); checks += 1 }
    static func close(_ a: CGFloat?, _ b: CGFloat, _ label: String) { check(abs((a ?? -100) - b) < 0.0001, label) }

    @MainActor static func main() async throws {
        let gap = [LyricLine(time: 10, text: "123456", endTime: 12), LyricLine(time: 17, text: "Next", endTime: 19)]
        close(LyricClock.moment(at: 11, in: gap)?.progress, 0.5, "explicit end interpolates vocal duration")
        for t in [12.0, 13, 16.999] { close(LyricClock.moment(at: t, in: gap)?.progress, 1, "holds during trailing gap") }
        check(LyricClock.moment(at: 17, in: gap)?.identity == 1, "switch at next source start")
        close(LyricClock.moment(at: 17, in: gap)?.progress, 0, "next line starts empty")
        check(LyricClock.moment(at: 9.99, in: gap) == nil, "intro stays empty")
        check(LyricClock.moment(at: .nan, in: gap) == nil, "nonfinite playback rejected")
        let words = [LyricLine(time: 10, text: "iiiWW", endTime: 12, segments: [
            LyricSegment(time: 10, endTime: 10.2, text: "iii"), LyricSegment(time: 10.8, endTime: 12, text: "WW")
        ]), gap[1]]
        let moment = LyricClock.moment(at: 11.4, in: words)!
        close(moment.highlight?.fraction, 0.5, "nonuniform token time")
        check(moment.highlight?.prefixBefore == "iii" && moment.highlight?.prefixThrough == "iiiWW", "token boundaries preserved")
        let font = NSFont.systemFont(ofSize: 24)
        let measured = LyricHighlightLayout.progress(moment.highlight!, text: moment.text, font: font)
        let before = ("iii" as NSString).size(withAttributes: [.font:font]).width
        let all = ("iiiWW" as NSString).size(withAttributes: [.font:font]).width
        close(measured, (before + (all - before) * 0.5) / all, "actual proportional font width")
        check(abs(measured - moment.progress) > 0.02, "glyph widths differ from character count")
        close(LyricClock.moment(at: 10.5, in: words)?.progress, 0.6, "inter-token rest holds completed prefix")
        for t in [12.0, 15, 16.999] { close(LyricClock.moment(at: t, in: words)?.progress, 1, "word end holds complete") }
        let clips = LyricHighlightLayout.clipRects(moment.highlight!, text: moment.text, font: font, rect: NSRect(x:0,y:0,width:40,height:100))
        check(!clips.isEmpty && clips.allSatisfy { $0.width >= 0 && $0.minX >= 0 }, "wrapped glyph clipping has valid prefix rects")
        let ordinary = [LyricLine(time: 10, text: "Hello"), LyricLine(time: 13, text: "World")]
        close(LyricClock.moment(at: 11.5, in: ordinary)?.progress, 0.5, "ordinary gap preserved")
        let long = [LyricLine(time: 10, text: "Hello"), LyricLine(time: 70, text: "World")]
        check(LyricClock.moment(at: 18, in: long)?.timingFidelity == .estimated, "start-only marked estimated")
        close(LyricClock.moment(at: 18, in: long)?.progress, 1, "extreme gap scan bounded")
        check(LyricClock.moment(at: 69.9, in: long)?.identity == 0 && LyricClock.moment(at:70,in:long)?.identity == 1, "estimate never changes switching")
        let lengthy = [LyricLine(time:10,text:String(repeating:"word",count:20)), LyricLine(time:70,text:"next")]
        close(LyricClock.moment(at: 26, in: lengthy)?.progress, 1, "long text scan capped at16s")
        let invalid = LyricLine(time: 10, text: "AB", endTime: 9, segments: [LyricSegment(time: 10, endTime: 9, text: "AB")])
        check(invalid.endTime == nil && invalid.segments.isEmpty, "malformed timing safely downgrades")
        let overlap = LyricLine(time:10,text:"AB",endTime:12,segments:[LyricSegment(time:10,endTime:11.5,text:"A"),LyricSegment(time:11,endTime:12,text:"B")])
        check(overlap.segments.isEmpty && overlap.timingFidelity == .lineWithEnd, "overlapping word times downgrade")
        let document = LyricParser.parseDocument("[offset:500]\n[00:10.00]Hi\n[00:12.00]Next")
        close(LyricClock.moment(at:10.5,in:document)?.progress,0.5,"document offset applied to position once")
        check(document.metadata.lyricOffset == 0.5 && document.normalizedLines[0].time == 9.5, "normalized compatibility array offset")
        check(LyricClock.moment(at:10.5,in:document) == LyricClock.moment(at:10.5,in:document.normalizedLines), "document and compatibility clock agree")
        check(LyricParser.parse("[offset:-500]\n[00:10.00]Hi")[0].time == 10.5, "negative offset normalized")
        check(LyricParser.parse("[99:nan]No\n[00:Infinity]No").isEmpty, "invalid LRC timestamps rejected")
        let krc = LyricParser.parseKRC("[offset:500]\n[10000,2000]<0,200,0>iii<800,1200,0>WW\n[17000,1000]<0,1000,0>Next")
        check(krc[0].time == 9.5 && krc[0].endTime == 11.5 && krc[0].segments[1].time == 10.3, "KRC duration relative token + offset")
        let yrc = LyricParser.parseYRC("[10000,2000](10000,200,0)iii(10800,1200,0)WW")
        check(yrc[0].segments[1].time == 10.8 && yrc[0].timingFidelity == .word, "YRC absolute tokens")
        check(LyricParser.parseYRC("[10000,2000](10000,0,0)iii(10800,1200,0)WW")[0].segments.isEmpty, "zero word duration rejected")
        let netease = NetEaseLyricsSource()
        let richData = try JSONSerialization.data(withJSONObject:["code":200,"yrc":["lyric":"[10000,2000](10000,200,0)iii(10800,1200,0)WW"],"lrc":["lyric":"[00:10]iiiWW"]])
        check(try netease.parseLyrics(richData)?[0].timingFidelity == .word, "NetEase prefers validated richer payload")
        let plainData = try JSONSerialization.data(withJSONObject:["code":200,"yrc":["lyric":"bad"],"lrc":["lyric":"[00:10]Hello"]])
        check(try netease.parseLyrics(plainData)?[0].text == "Hello", "bad YRC returns ordinary LRC")
        let unsupportedData = try JSONSerialization.data(withJSONObject:["code":200,"yrc":["lyric":"bad"]])
        check(try netease.parseLyrics(unsupportedData) == nil, "partial rich schema permits old-endpoint fallback")
        let emptyData = try JSONSerialization.data(withJSONObject:["code":200,"lrc":["lyric":""]])
        check(try netease.parseLyrics(emptyData) == [], "explicit empty LRC is a legitimate MISS")
        let track = SpotifyTrack(name:"Song",artist:"Artist",album:"Album",duration:200)
        func mux(_ source: String, words: Bool = false) throws -> Data {
            var line: [String:Any] = ["start":10000,"end":12000,"text":"AB"]
            if words { line["words"] = [["text":"A","start":10000,"end":10500],["text":"B","start":11000,"end":12000]] }
            return try JSONSerialization.data(withJSONObject:["track":["title":"Song","artist":"Artist","album":"Album","duration":200],"meta":["source":["id":source,"name":source,"url":"https://example.com"],"level":words ? "word" : "line"],"lines":[line,["start":17000,"end":19000,"text":"Next"]]])
        }
        let muxLines = try LRCMuxLyricsSource().parse(mux("kugou"),for:track)
        check(muxLines[0].endTime == 12 && !muxLines[0].endTimeIsEstimated, "LRCMux genuine upstream line end retained")
        close(LyricClock.moment(at:12,in:muxLines)?.progress,1,"provider trailing gap")
        check(try LRCMuxLyricsSource().parse(mux("lrclib"),for:track)[0].endTimeIsEstimated, "known synthesized LRCMux ends identified")
        check(try LRCMuxLyricsSource().parse(mux("netease",words:true),for:track)[0].timingFidelity == .word, "optional LRCMux words retained")
        // Repeated text, seek backwards, repeat and restart remain position-driven and stateless.
        for t in [16.9, 10.0, 17.0, 11.0, 10.0, 16.0] {
            check(LyricClock.moment(at:t,in:gap)?.identity == (t >= 17 ? 1 : 0), "seek/repeat line identity")
        }
        let calls = Calls()
        let client = LyricsClient(sources:[{ _ in [LyricLine(time:Double(await calls.next()),text:"same metadata",endTime:5)] }])
        let first = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"spotify:track:A")
        let cached = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"spotify:track:A")
        let cachedCalls = await calls.count
        check(first == cached && cachedCalls == 1, "same native identity cached")
        let other = try await client.syncedLyrics(for:track,playerSource:"NetEase Music",nativeTrackID:"A")
        let otherCalls = await calls.count
        check(other != first && otherCalls == 2, "same metadata across players not reused")
        _ = try await client.syncedLyrics(for:track,playerSource:"Spotify",nativeTrackID:"spotify:track:B")
        check(await calls.count == 3, "same player new native ID not reused")
        check(client.selectedDocument?.metadata.platformTrackID == nil, "array-only source does not forge player ID as lyric source identity")
        let fixture = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let actual = LyricParser.parseYRC(fixture)
        check(actual.count == 47 && actual.flatMap(\.segments).count == 411, "real redacted YRC shape retained")
        for line in actual {
            check(line.segments.map(\.text).joined() == line.text && line.timingFidelity == .word, "real fixture word validation")
            let next = LyricLine(time: line.endTime! + 5, text: "next")
            close(LyricClock.moment(at: line.endTime! + 2, in: [line, next])?.progress, 1, "real vocal end holds during gap")
        }
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<1000 { _ = LyricClock.moment(at:11.4,in:words) }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        check(elapsed < 1, "1000 clock moments under1second")
        print("Lyric timing tests: \(checks) PASS; 1000 moments \(elapsed)s")
    }
}
