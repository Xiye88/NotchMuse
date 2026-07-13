import Foundation

enum SelfTests {
    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Self-test failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func run() {
        let parsed = LyricParser.parse("[00:01.50]Hello\n[00:03.00]World")
        check(parsed == [
            LyricLine(time: 1.5, text: "Hello"),
            LyricLine(time: 3.0, text: "World")
        ], "parses timestamped lines")

        let repeated = LyricParser.parse("[00:01.00][00:02.00]Again")
        check(repeated == [
            LyricLine(time: 1.0, text: "Again"),
            LyricLine(time: 2.0, text: "Again")
        ], "parses repeated timestamps")

        check(LyricClock.currentLine(at: 0.5, in: parsed) == nil, "has no lyric before the first line")
        check(LyricClock.currentLine(at: 3.2, in: parsed) == "World", "selects the current lyric")

        var scroll = ScrollState()
        check(scroll.visibleText("short", maxCharacters: 10) == "short", "does not scroll short text")
        for _ in 0..<7 {
            scroll.advance()
        }
        check(scroll.visibleText("abcdefghij", maxCharacters: 4) == "bcde", "scrolls long text")

        testTrackMatcher()

        print("Self-tests passed")
    }

    private static func testTrackMatcher() {
        func track(_ name: String, _ artist: String = "Artist", _ duration: Double = 200) -> SpotifyTrack {
            SpotifyTrack(name: name, artist: artist, album: "Album", duration: duration)
        }

        func candidate(_ title: String, _ artists: [String] = ["Artist"], _ durationMs: Int = 200_000) -> TrackMatcher.Candidate {
            TrackMatcher.Candidate(title: title, artists: artists, durationMs: durationMs)
        }

        let accepted: [(SpotifyTrack, TrackMatcher.Candidate)] = [
            (track("成都", "赵雷", 328), candidate("成都", ["赵雷"], 328_020)),
            (track("Hello!", "Adele"), candidate("hello", ["ADELE"])),
            (track("Beyonce", "Beyonce"), candidate("Beyonce", ["Beyonce"])),
            (track("Song (feat. Guest)", "Artist, Guest"), candidate("Song", ["Artist", "Guest"])),
            (track("Song(feat.Live)"), candidate("Song")),
            (track("Song", "Artist feat. Guest"), candidate("Song (feat. Guest)", ["Artist"])),
            (track("Song - 2011 Remaster"), candidate("Song (Remastered 2011)")),
            (track("Song", "Artist & Guest"), candidate("Song", ["Artist", "Guest"])),
            (track("Song", "Artist, Guest"), candidate("Song", ["Guest"])),
            (track("Cancion", "Jose"), candidate("Canción", ["José"])),
            (track("Song"), candidate("Song", ["Artist"], 212_000))
        ]
        for (source, result) in accepted {
            check(TrackMatcher.score(source, candidate: result) >= TrackMatcher.acceptanceThreshold, "accepts \(source.name) by \(source.artist)")
        }

        let rejected: [(SpotifyTrack, TrackMatcher.Candidate)] = [
            (track("Song", "AB, C"), candidate("Song", ["A", "BC"])),
            (track("Song", "AC/DC"), candidate("Song", ["DC"])),
            (track("Song", "Earth, Wind & Fire"), candidate("Song", ["Fire"])),
            (track("成都", "赵雷", 328), candidate("成都", ["其他歌手"], 328_020)),
            (track("成都", "赵雷", 328), candidate("成都", ["赵雷"], 340_001)),
            (track("Hello"), candidate("Hello World")),
            (track("Hello World"), candidate("Hello")),
            (track("Song (Live)"), candidate("Song")),
            (track("Song"), candidate("Song (Live)")),
            (track("Song (Remix)"), candidate("Song")),
            (track("Song (Acoustic)"), candidate("Song")),
            (track("Song"), candidate("Song (Instrumental)")),
            (track("Song (Live Acoustic)"), candidate("Song (Live)")),
            (track("Song"), candidate("Different", ["Artist"], 200_000))
        ]
        for (source, result) in rejected {
            check(TrackMatcher.score(source, candidate: result) < TrackMatcher.acceptanceThreshold, "rejects \(source.name) by \(source.artist)")
        }

        let source = track("Song", "Artist", 200)
        let ranked = [
            candidate("Song", ["Artist"], 208_000),
            candidate("Song", ["Artist"], 200_000),
            candidate("Wrong", ["Artist"], 200_000)
        ]
        check(TrackMatcher.bestMatchIndex(for: source, candidates: ranked) == 1, "selects the highest score")

        let ambiguous = [
            candidate("Song", ["Artist"], 200_000),
            candidate("Song", ["Artist"], 204_000)
        ]
        check(TrackMatcher.bestMatchIndex(for: source, candidates: ambiguous) == nil, "rejects ambiguous matches")

        check(TrackMatcher.bestMatchIndex(for: source, candidates: [candidate("Wrong")]) == nil, "rejects a non-match")
    }
}
