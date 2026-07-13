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
        testLyricsCache()
        testLRCLIBRequest()
        testLRCMuxRequest()
        testLRCMuxResponse()
        testLRCMuxLanguageConflict()

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await testLyricsClient()
            if ProcessInfo.processInfo.environment["LIVE_LYRICS_TESTS"] == "1" {
                await testLRCMuxLive()
            }
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now()) != .success {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        print("Self-tests passed")
    }

    private static func testLyricsCache() {
        var cache = LyricsCache(capacity: 100)
        let line = [LyricLine(time: 1, text: "cached")]

        cache.insert([], for: "empty")
        check(cache.value(for: "empty") == nil, "does not cache empty results")

        for index in 0...100 {
            cache.insert(line, for: "track-\(index)")
        }
        check(cache.value(for: "track-0") == nil, "evicts the oldest result over capacity")
        check(cache.value(for: "track-100") == line, "keeps the newest cached result")
        check(cache.value(for: "track-100", bypass: true) == nil, "bypasses cached results on refresh")
    }

    private static func testLRCMuxRequest() {
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "The Album", duration: 201.6)
        let items = URLComponents(url: LRCMuxLyricsSource().request(for: track).url!, resolvingAgainstBaseURL: false)?.queryItems
        check(items?.contains(URLQueryItem(name: "album", value: "The Album")) == true, "sends album to lrcmux")
        check(items?.contains(URLQueryItem(name: "duration", value: "202")) == true, "sends duration to lrcmux in seconds")
        check(items?.contains(URLQueryItem(name: "format", value: "json")) == true, "requests JSON from lrcmux")
    }

    private static func testLRCLIBRequest() {
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        let request = LyricsClient.lrclibRequest(for: track)
        check(request.timeoutInterval == 6, "uses a six-second LRCLIB timeout")
        check(request.value(forHTTPHeaderField: "User-Agent") == "MenuBarLyrics/0.1 (macOS)", "sets the LRCLIB user agent")
    }

    private static func testLRCMuxResponse() {
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        let data = lrcMuxJSON(title: "Song", artist: "Artist", album: "Album", duration: 200, isrc: "USABC1234567", texts: ["Hello", "World"])
        let lines = try! LRCMuxLyricsSource().parse(data, for: track)
        check(lines == [LyricLine(time: 1, text: "Hello"), LyricLine(time: 2, text: "World")], "parses official lrcmux track/meta/lines JSON")

        let wrongTrack = SpotifyTrack(name: "Different", artist: "Artist", album: "Album", duration: 200)
        check((try! LRCMuxLyricsSource().parse(data, for: wrongTrack)).isEmpty, "reuses track matching for lrcmux metadata")
    }

    private static func testLRCMuxLanguageConflict() {
        let korean = SpotifyTrack(name: "LOVE SCENARIO", artist: "iKON", album: "Return", duration: 209)
        let wrongJapanese = lrcMuxJSON(
            title: "LOVE SCENARIO", artist: "Ikon", album: "Return", duration: 209,
            isrc: "KRA401800015", texts: ["恋に落ちた僕たちは", "消えはしない思い出になる"]
        )
        check((try! LRCMuxLyricsSource().parse(wrongJapanese, for: korean)).isEmpty, "rejects the LOVE SCENARIO Japanese conflict")

        let normalKorean = lrcMuxJSON(
            title: "LOVE SCENARIO", artist: "Ikon", album: "Return", duration: 209,
            isrc: "KRA401800015", texts: ["사랑을 했다 우리가 만나", "지우지 못할 추억이 됐다"]
        )
        check(!(try! LRCMuxLyricsSource().parse(normalKorean, for: korean)).isEmpty, "keeps normal Korean lyrics")

        let japanese = SpotifyTrack(name: "LOVE SCENARIO Japanese ver.", artist: "iKON", album: "JP Edition", duration: 209)
        let validJapanese = lrcMuxJSON(
            title: "LOVE SCENARIO Japanese ver.", artist: "Ikon", album: "JP Edition", duration: 209,
            isrc: "KRA401800015", texts: ["恋に落ちた僕たちは", "消えはしない思い出になる"]
        )
        check(!(try! LRCMuxLyricsSource().parse(validJapanese, for: japanese)).isEmpty, "keeps explicitly marked Japanese lyrics")
    }

    private static func lrcMuxJSON(title: String, artist: String, album: String, duration: Int, isrc: String, texts: [String]) -> Data {
        let lines = texts.enumerated().map { ["text": $0.element, "start": ($0.offset + 1) * 1000, "end": ($0.offset + 2) * 1000] as [String: Any] }
        return try! JSONSerialization.data(withJSONObject: [
            "track": ["isrc": isrc, "title": title, "artist": artist, "album": album, "duration": duration],
            "meta": ["source": ["id": "test", "name": "Test", "url": "https://example.com"], "level": "line"],
            "lines": lines
        ])
    }

    @MainActor
    private static func testLyricsClient() async {
        let track = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        let calls = SourceCalls()
        let first = [LyricLine(time: 1, text: "first")]
        let refreshed = [LyricLine(time: 2, text: "refreshed")]
        let client = LyricsClient(sources: [
            { _ in
                _ = await calls.record(0)
                throw NSError(domain: "SelfTests", code: 1)
            },
            { _ in
                _ = await calls.record(1)
                return []
            },
            { _ in
                let count = await calls.record(2)
                return count == 1 ? first : refreshed
            }
        ])

        let fetched = try! await client.syncedLyrics(for: track)
        check(fetched == first, "returns the first non-empty result despite one source failure")
        var counts = await calls.snapshot()
        check(counts == [1, 1, 1], "calls all three configured sources")

        let cached = try! await client.syncedLyrics(for: track)
        check(cached == first, "returns cached lyrics")
        counts = await calls.snapshot()
        check(counts == [1, 1, 1], "cache hit does not call sources")

        let refresh = try! await client.syncedLyrics(for: track, bypassCache: true)
        check(refresh == refreshed, "bypassCache refreshes and updates lyrics")
        counts = await calls.snapshot()
        check(counts == [2, 2, 2], "bypassCache calls all sources again")

        let refreshedCache = try! await client.syncedLyrics(for: track)
        check(refreshedCache == refreshed, "caches refreshed lyrics")
        counts = await calls.snapshot()
        check(counts == [2, 2, 2], "refreshed cache does not call sources")

        let cancellation = CancellationProbe()
        let raced = await LyricsClient.firstNonEmpty([
            { _ in
                await cancellation.recordStarted()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch is CancellationError {
                    await cancellation.recordCancelled()
                } catch {}
                if Task.isCancelled {
                    await cancellation.recordCancelled()
                }
                return []
            },
            { _ in
                await cancellation.waitUntilStarted()
                return first
            }
        ], for: track)
        check(raced == first, "returns the first non-empty raced result")
        let wasCancelled = await cancellation.wasCancelled()
        check(wasCancelled, "cancels pending lyric sources after finding lyrics")
    }

    private static func testLRCMuxLive() async {
        let source = LRCMuxLyricsSource()
        let conflict = SpotifyTrack(name: "LOVE SCENARIO", artist: "iKON", album: "Return", duration: 209)
        let conflictLines = try! await source.syncedLyrics(for: conflict)
        check(conflictLines.isEmpty, "rejects the live LOVE SCENARIO conflict")

        let representatives = [
            SpotifyTrack(name: "成都", artist: "赵雷", album: "无法长大", duration: 328),
            SpotifyTrack(name: "Shape of You", artist: "Ed Sheeran", album: "÷", duration: 234)
        ]
        for track in representatives {
            let lines = try! await source.syncedLyrics(for: track)
            check(!lines.isEmpty, "keeps live LRC for \(track.name)")
        }
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
            (track("Song", "Artist & Guest"), candidate("Song", ["Guest", "Artist"])),
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

private actor SourceCalls {
    private(set) var counts = [0, 0, 0]

    func record(_ source: Int) -> Int {
        counts[source] += 1
        return counts[source]
    }

    func snapshot() -> [Int] {
        counts
    }
}

private actor CancellationProbe {
    private var started = false
    private var cancelled = false

    func recordStarted() {
        started = true
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func recordCancelled() {
        cancelled = true
    }

    func wasCancelled() -> Bool {
        cancelled
    }
}
