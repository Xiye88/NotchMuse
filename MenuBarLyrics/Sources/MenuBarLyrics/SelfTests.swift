import Foundation

enum SelfTests {
    static func run() {
        let parsed = LyricParser.parse("[00:01.50]Hello\n[00:03.00]World")
        assert(parsed == [
            LyricLine(time: 1.5, text: "Hello"),
            LyricLine(time: 3.0, text: "World")
        ])

        let repeated = LyricParser.parse("[00:01.00][00:02.00]Again")
        assert(repeated == [
            LyricLine(time: 1.0, text: "Again"),
            LyricLine(time: 2.0, text: "Again")
        ])

        assert(LyricClock.currentLine(at: 0.5, in: parsed) == nil)
        assert(LyricClock.currentLine(at: 3.2, in: parsed) == "World")

        var scroll = ScrollState()
        assert(scroll.visibleText("short", maxCharacters: 10) == "short")
        for _ in 0..<7 {
            scroll.advance()
        }
        assert(scroll.visibleText("abcdefghij", maxCharacters: 4) == "bcde")

        let track = SpotifyTrack(name: "成都", artist: "赵雷", album: "无法长大", duration: 328)
        assert(NetEaseLyricsSource.matches(track, title: "成都", artists: ["赵雷"], durationMs: 328_020))
        assert(!NetEaseLyricsSource.matches(track, title: "成都", artists: ["其他歌手"], durationMs: 328_020))
        assert(!NetEaseLyricsSource.matches(track, title: "成都", artists: ["赵雷"], durationMs: 341_000))

        print("Self-tests passed")
    }
}
