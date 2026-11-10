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
    static var failures = 0
    static func check(_ condition: Bool, _ label: String) { checks += 1; if !condition { failures += 1; print("FAIL: \(label)") } }
    static func close(_ a: CGFloat?, _ b: CGFloat, _ label: String) { check(abs((a ?? -100) - b) < 0.0001, label) }

    @MainActor static func main() async throws {
        check(LyricHighlightLayout.verticalStart(glyphCount:40,rows:11,progress:1,staticText:true) == 0, "fully lit static vertical lyrics retain their opening glyphs")
        check(LyricHighlightLayout.verticalStart(glyphCount:40,rows:11,progress:1,staticText:false) == 18, "real timed vertical lyrics retain their completed viewport")
        check(LyricHighlightLayout.verticalStart(glyphCount:40,rows:11,progress:0.5,staticText:false) == 9, "real timed vertical viewport still follows timing")
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
        for text in ["短句", String(repeating: "长句", count: 30), "One two three four five six seven eight"] {
            for nextStart in [13.0, 70.0] {
                let staticLines = [LyricLine(time: 10, text: text), LyricLine(time: nextStart, text: "Next")]
                for t in [10.0, 10.5, nextStart - 0.001, 10.25] {
                    let m = LyricClock.moment(at: t, in: staticLines)!
                    close(m.progress, 1, "LRC short/long gaps stay fully lit from source start, including seek")
                    check(m.highlight == nil && m.timingFidelity == .lineStartOnly && m.identity == 0, "static LRC keeps source fidelity and identity")
                }
                check(LyricClock.moment(at: nextStart, in: staticLines)?.identity == 1, "static LRC switches only at source start")
            }
        }
        for line in [LyricLine(time: 10, text: "AB", endTime: 15, endTimeIsEstimated: true),
                     LyricLine(time: 10, text: "AB", endTime: 15, segments: [
                        LyricSegment(time: 10, endTime: 12, text: "A"),
                        LyricSegment(time: 12, endTime: 15, text: "B", synthetic: true)], endTimeIsEstimated: true)] {
            for t in [10.0, 11, 14.9, 18.999] {
                let m = LyricClock.moment(at: t, in: [line, LyricLine(time: 19, text: "Next")])!
                close(m.progress, 1, "estimated ends and synthetic words do not animate")
                check(m.highlight == nil && m.timingFidelity == .estimated, "synthetic word timing never becomes a real highlight")
            }
        }
        let syntheticWithRealEnd = LyricLine(time:10,text:"AB",endTime:15,segments:[
            LyricSegment(time:10,endTime:12,text:"A",synthetic:true), LyricSegment(time:12,endTime:15,text:"B",synthetic:true)])
        let realEndMoment = LyricClock.moment(at:12.5,in:[syntheticWithRealEnd])!
        close(realEndMoment.progress,0.5,"synthetic words do not discard an independent real line end")
        check(realEndMoment.highlight == nil && realEndMoment.timingFidelity == .lineWithEnd,"synthetic words downgrade to genuine line-end animation")
        let vocalGap = [LyricLine(time: 10, text: "AB", endTime: 15), LyricLine(time: 19, text: "Next", endTime: 21)]
        close(LyricClock.moment(at: 12.5, in: vocalGap)?.progress, 0.5, "10–15 real line end remains proportional")
        for t in [15.0, 17, 18.999] { close(LyricClock.moment(at: t, in: vocalGap)?.progress, 1, "10–15 vocal end holds to next19") }
        check(LyricClock.moment(at: 19, in: vocalGap)?.identity == 1, "next19 switches at source time")
        let earlyWords = LyricLine(time: 10, text: "AB", endTime: 17, segments: [
            LyricSegment(time: 10, endTime: 12, text: "A"), LyricSegment(time: 13, endTime: 15, text: "B")])
        close(LyricClock.moment(at: 14, in: [earlyWords])?.highlight?.fraction, 0.5, "real words outrank later real line end")
        for t in [15.0, 16, 18.999] { close(LyricClock.moment(at: t, in: [earlyWords, vocalGap[1]])?.progress, 1, "last real word ends before line tail and stays complete") }
        let invalid = LyricLine(time: 10, text: "AB", endTime: 9, segments: [LyricSegment(time: 10, endTime: 9, text: "AB")])
        check(invalid.endTime == nil && invalid.segments.isEmpty, "malformed timing safely downgrades")
        let overlap = LyricLine(time:10,text:"AB",endTime:12,segments:[LyricSegment(time:10,endTime:11.5,text:"A"),LyricSegment(time:11,endTime:12,text:"B")])
        check(overlap.segments.isEmpty && overlap.timingFidelity == .lineWithEnd, "overlapping word times downgrade")
        let document = LyricParser.parseDocument("[offset:500]\n[00:10.00]Hi\n[00:12.00]Next")
        check(LyricClock.moment(at:9.49,in:document) == nil && LyricClock.moment(at:9.5,in:document)?.identity == 0 && LyricClock.moment(at:11.5,in:document)?.identity == 1, "document offset applied to line selection once")
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
        let mixedYRC = "[offset:500]\n[10000,5000](10000,2000,0)A(13000,2000,0)B\n[19000,2000](19000,0,0)Bad"
        var mixedLines: [LyricLine] = []
        for lrc in ["[00:10]AB\n[00:19]Bad", ""] {
            let data = try JSONSerialization.data(withJSONObject: ["code":200,"yrc":["lyric":mixedYRC],"lrc":["lyric":lrc]])
            let parsed = try netease.parseLyrics(data) ?? []
            check(parsed.count == 2 && parsed.first?.timingFidelity == .word && parsed.last?.timingFidelity == .lineWithEnd, "one bad YRC word line cannot discard good words or real line ends, even with empty LRC")
            check(parsed.map(\.text) == ["AB", "Bad"] && parsed.first?.time == 9.5 && parsed.last?.endTime == 20.5, "mixed YRC preserves text and applies offset once")
            mixedLines = parsed
        }
        let allBadWords = try JSONSerialization.data(withJSONObject: ["code":200,"yrc":["lyric":"[10000,5000](10000,0,0)Body"],"lrc":["lyric":""]])
        check(try netease.parseLyrics(allBadWords) == [LyricLine(time:10,text:"Body",endTime:15)], "all invalid words still preserve valid YRC line body and end")
        let emptyYRC = try JSONSerialization.data(withJSONObject: ["code":200,"yrc":["lyric":""],"lrc":["lyric":"[00:10]Fallback"]])
        check(try netease.parseLyrics(emptyYRC) == [LyricLine(time:10,text:"Fallback")], "empty YRC retains LRC fallback")
        let allEmpty = try JSONSerialization.data(withJSONObject: ["code":200,"yrc":["lyric":""],"lrc":["lyric":""]])
        check(try netease.parseLyrics(allEmpty) == [], "all empty retains legitimate no-lyrics result")
        let track = SpotifyTrack(name:"Song",artist:"Artist",album:"Album",duration:200)
        let mixedCandidate = LyricsCandidate(document:TimedLyricDocument(lines:mixedLines),provider:"NetEase",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let plainCandidate = LyricsCandidate(document:TimedLyricDocument(lines:mixedLines.map { LyricLine(time:$0.time,text:$0.text) }),provider:"LRCLIB",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let selected = LyricsSelection.select([plainCandidate,mixedCandidate],context:LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)).winner
        check(selected?.document.lines == mixedLines && selected?.document.lines.first?.segments.count == 2 && selected?.document.lines.last?.endTime == 20.5, "equal-identity selection retains mixed YRC words and ends instead of earlier LRC")
        let noTailYRC = try JSONSerialization.data(withJSONObject: ["code":200,"yrc":["lyric":"[10000,5000](10000,2000,0)A(13000,2000,0)B\n[19000,0](19000,0,0)Bad"],"lrc":["lyric":"[00:10]AB\n[00:19]Bad"]])
        let noTailLines = try netease.parseLyrics(noTailYRC) ?? []
        let noTailCandidate = LyricsCandidate(document:TimedLyricDocument(lines:noTailLines),provider:"NetEase",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let noTailPlain = LyricsCandidate(document:TimedLyricDocument(lines:noTailLines.map { LyricLine(time:$0.time,text:$0.text) }),provider:"LRCLIB",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let noTailSelected = LyricsSelection.select([noTailPlain,noTailCandidate],context:LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)).winner
        check(noTailLines.first?.segments.count == 2 && noTailLines.last?.endTime == nil, "zero-duration bad YRC row downgrades only itself to source start")
        check(noTailSelected?.document.lines == noTailLines && noTailSelected?.document.lines.first?.segments.count == 2, "equal-identity selection cannot discard real words because another YRC row lacks an end")
        let verifiedPlain = LyricsCandidate(document:noTailPlain.document,provider:"NetEaseExactID (Preview)",sourcePlatform:"netease",sourceTrackID:"verified",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200,liveIdentityVerified:true)
        check(LyricsSelection.select([noTailCandidate,verifiedPlain],context:LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)).winner == verifiedPlain, "partial real timing cannot outrank higher recording identity")
        let syntheticOnly = noTailLines.map { LyricLine(time:$0.time,text:$0.text,segments:[LyricSegment(time:$0.time,endTime:$0.time + 1,text:$0.text,synthetic:true)]) }
        let syntheticCandidate = LyricsCandidate(document:TimedLyricDocument(lines:syntheticOnly),provider:"NetEase",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        check(LyricsSelection.select([syntheticCandidate,noTailPlain],context:LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)).winner == noTailPlain, "synthetic-only timing does not elevate a candidate over genuine source starts")
        check(noTailCandidate.document.timingFidelity == .lineStartOnly, "partial genuine timing does not mislabel the document as complete word timing")
        let syntheticEstimated = noTailLines.map { LyricLine(time:$0.time,text:$0.text,endTime:$0.time + 1,segments:[LyricSegment(time:$0.time,endTime:$0.time + 1,text:$0.text,synthetic:true)],endTimeIsEstimated:true) }
        let syntheticEstimatedCandidate = LyricsCandidate(document:TimedLyricDocument(lines:syntheticEstimated),provider:"NetEase",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        check(LyricsSelection.select([syntheticEstimatedCandidate,noTailPlain],context:LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)).winner == noTailPlain, "synthetic words plus estimated tails do not become partial genuine timing")
        let completeEnds = noTailLines.map { LyricLine(time:$0.time,text:$0.text,endTime:$0.time + 1) }
        let completeEndCandidate = LyricsCandidate(document:TimedLyricDocument(lines:completeEnds),provider:"QQ",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let completeWords = completeEnds.map { LyricLine(time:$0.time,text:$0.text,endTime:$0.endTime,segments:[LyricSegment(time:$0.time,endTime:$0.endTime!,text:$0.text)]) }
        let completeWordCandidate = LyricsCandidate(document:TimedLyricDocument(lines:completeWords),provider:"Kugou",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        let equalContext = LyricsSelectionContext(track:track,playerSource:"NetEase Cloud Music",nativeTrackID:nil,isrc:nil)
        check(LyricsSelection.select([noTailCandidate,completeEndCandidate],context:equalContext).winner == completeEndCandidate, "complete genuine line ends outrank partially timed documents")
        check(LyricsSelection.select([noTailCandidate,completeEndCandidate,completeWordCandidate],context:equalContext).winner == completeWordCandidate, "complete genuine words retain highest timing priority")
        let mixedSyntheticLines = [LyricLine(time:10,text:"AB",segments:[LyricSegment(time:10,endTime:11,text:"A"),LyricSegment(time:11,endTime:12,text:"B",synthetic:true)]),LyricLine(time:19,text:"Bad")]
        let mixedSyntheticCandidate = LyricsCandidate(document:TimedLyricDocument(lines:mixedSyntheticLines),provider:"NetEase",sourcePlatform:"netease",sourceTrackID:"fixture",sourceTitle:"Song",sourceArtist:"Artist",sourceAlbum:"Album",sourceDuration:200)
        check(LyricsSelection.select([mixedSyntheticCandidate,noTailPlain],context:equalContext).winner == noTailPlain, "mixed real and synthetic words without a true end cannot gain timing priority when the clock must render them statically")
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
        if CommandLine.arguments.count > 1 {
            let fixture = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
            let actual = LyricParser.parseYRC(fixture)
            check(actual.count == 47 && actual.flatMap(\.segments).count == 411, "real redacted YRC shape retained")
            for line in actual {
                check(line.segments.map(\.text).joined() == line.text && line.timingFidelity == .word, "real fixture word validation")
                let next = LyricLine(time: line.endTime! + 5, text: "next")
                close(LyricClock.moment(at: line.endTime! + 2, in: [line, next])?.progress, 1, "real vocal end holds during gap")
            }
        } else {
            print("SKIP: optional redacted real YRC fixture not supplied; regression fixtures only")
        }
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<1000 { _ = LyricClock.moment(at:11.4,in:words) }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        check(elapsed < 1, "1000 clock moments under1second")
        fflush(stdout)
        precondition(failures == 0, "\(failures) lyric timing checks failed")
        print("Lyric timing tests: \(checks) PASS; 1000 moments \(elapsed)s")
    }
}
