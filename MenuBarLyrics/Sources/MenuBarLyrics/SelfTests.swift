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

        print("Self-tests passed")
    }
}
