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
            (track("Song", "Artist feat. Guest"), candidate("Song (feat. Guest)", ["Artist"])),
            (track("Song - 2011 Remaster"), candidate("Song (Remastered 2011)")),
            (track("Song", "Artist & Guest"), candidate("Song", ["Artist", "Guest"])),
            (track("Song", "Artist, Guest"), candidate("Song", ["Guest"])),
            (track("Cancion", "Jose"), candidate("Canción", ["José"])),
            (track("Song"), candidate("Song", ["Artist"], 212_000))
        ]
        for (source, result) in accepted {
            assert(TrackMatcher.score(source, candidate: result) >= TrackMatcher.acceptanceThreshold)
        }

        let rejected: [(SpotifyTrack, TrackMatcher.Candidate)] = [
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
            assert(TrackMatcher.score(source, candidate: result) < TrackMatcher.acceptanceThreshold)
        }

        let source = track("Song", "Artist", 200)
        let ranked = [
            candidate("Song", ["Artist"], 208_000),
            candidate("Song", ["Artist"], 200_000),
            candidate("Wrong", ["Artist"], 200_000)
        ]
        assert(TrackMatcher.bestMatchIndex(for: source, candidates: ranked) == 1)

        let ambiguous = [
            candidate("Song", ["Artist"], 200_000),
            candidate("Song", ["Artist"], 204_000)
        ]
        assert(TrackMatcher.bestMatchIndex(for: source, candidates: ambiguous) == nil)

        assert(TrackMatcher.bestMatchIndex(for: source, candidates: [candidate("Wrong")]) == nil)
    }
}
