import Foundation
import AppKit

enum SelfTests {
    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Self-test failed: \(message)\n", stderr)
            exit(1)
        }
    }

    @MainActor static func run() {
        testBrandStyle()
        testMenuBarSafety()

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

        let progressLines = [
            LyricLine(time: 1, text: "One"),
            LyricLine(time: 3, text: "Three"),
            LyricLine(time: 7, text: "Seven")
        ]
        check(LyricClock.moment(at: 0.5, in: progressLines) == nil, "has no lyric before the first line")
        check(LyricClock.moment(at: 1, in: progressLines)?.progress == 0, "starts lyric progress at zero")
        check(LyricClock.moment(at: 2, in: progressLines)?.progress == 0.5, "tracks lyric progress between lines")
        check(LyricClock.moment(at: 3, in: progressLines)?.progress == 0, "resets lyric progress on the next line")
        check(LyricClock.moment(at: 10, in: progressLines)?.progress == 1, "clamps final lyric progress at one")
        check(LyricClock.currentLine(at: 3.2, in: parsed) == "World", "selects the current lyric")

        testSmoothScroll()
        testOverlayGeometry()
        check(OverlayLaneGeometry.centeredTextY(laneHeight: 32, lineHeight: 16) == 8, "centers lyrics vertically in the menu bar")

        testTrackMatcher()
        testLyricsHTTP()
        testLyricsCache()
        testLRCLIBRequest()
        testLRCLIBFixtures()
        testLRCMuxRequest()
        testLRCMuxResponse()
        testLRCMuxLanguageConflict()
        testQQMusicRequests()
        testQQMusicFixtures()
        testKugouRequests()
        testKugouFixtures()

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await testLyricsClient()
            if ProcessInfo.processInfo.environment["LRCLIB_LIVE_TESTS"] == "1" {
                await testLRCLIBLive()
            }
            if ProcessInfo.processInfo.environment["LIVE_LYRICS_TESTS"] == "1" {
                await testLRCMuxLive()
            }
            if ProcessInfo.processInfo.environment["QQ_LIVE_TESTS"] == "1" {
                await testQQMusicLive()
            }
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now()) != .success {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        print("Self-tests passed")
    }

    private static func testBrandStyle() {
        check(BrandStyle.gradientColors.count == 3, "uses three brand gradient colors")
        for (color, expected) in zip(BrandStyle.gradientColors, [(232, 121, 36), (200, 90, 18), (150, 58, 8)]) {
            var red = CGFloat.zero
            var green = CGFloat.zero
            var blue = CGFloat.zero
            var alpha = CGFloat.zero
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            check((red, green, blue) == (CGFloat(expected.0) / 255, CGFloat(expected.1) / 255, CGFloat(expected.2) / 255), "uses exact brand gradient RGB values")
        }
    }

    @MainActor private static func testMenuBarSafety() {
        check(!MenuBarSafety.isExplicitlyHidden(nil), "treats a missing AXHidden attribute as visible")
        check(!MenuBarSafety.isExplicitlyHidden("unexpected" as CFString), "treats an invalid AXHidden value as visible")
        check(!MenuBarSafety.isExplicitlyHidden(false as NSNumber), "treats AXHidden false as visible")
        check(MenuBarSafety.isExplicitlyHidden(true as NSNumber), "skips explicitly hidden AX elements")
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

    private static func testLyricsHTTP() {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 429, httpVersion: nil, headerFields: nil)!
        do {
            _ = try LyricsHTTP.validate(data: Data(), response: response)
            check(false, "rejects a 429 lyrics response")
        } catch let error as URLError {
            check(error.code == .badServerResponse, "reports a 429 lyrics response as badServerResponse")
        } catch {
            check(false, "reports a 429 lyrics response as badServerResponse")
        }
    }

    private static func testSmoothScroll() {
        var scroll = ScrollState()
        scroll.reset(at: 100)

        check(scroll.offset(contentWidth: 80, viewportWidth: 100, at: 200) == 0, "does not scroll fitting text")
        check(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 100.8) == 0, "pauses at the scroll start")
        check(abs(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 101.9) - 28) < 0.01, "scrolls forward at 28 points per second")
        check(abs(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 102.9) - 56) < 0.01, "reaches the scroll endpoint")
        check(abs(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 103.5) - 56) < 0.01, "pauses at the scroll endpoint")
        check(abs(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 104.8) - 28) < 0.01, "scrolls back smoothly")
        check(abs(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 105.8)) < 0.01, "returns to the scroll start")

        scroll.reset(at: 300)
        check(scroll.offset(contentWidth: 156, viewportWidth: 100, at: 300.8) == 0, "reset restarts the initial pause")
    }

    private static func testOverlayGeometry() {
        let leftSafeArea = NSRect(x: 0, y: 924, width: 646, height: 32)
        let rightSafeArea = NSRect(x: 825, y: 924, width: 645, height: 32)
        let frames = OverlayLaneGeometry.frames(
            screenFrame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            auxiliaryTopLeftArea: leftSafeArea,
            auxiliaryTopRightArea: rightSafeArea,
            statusItemX: 1300,
            foregroundMenuMaxX: 600,
            menuBarHeight: 32
        )
        check(leftSafeArea.contains(frames.left), "keeps the left lyric lane inside the notch-safe area")
        check(rightSafeArea.contains(frames.right), "keeps the right lyric lane inside the notch-safe area")
        check(frames.left.maxX <= 646 && frames.right.minX >= 825, "keeps both lyric lanes out of the notch")
        check(frames.left.minX >= 608, "keeps the left lyric lane eight points after foreground menus")
        check(frames.right.maxX <= 1102, "reserves space before status items")
        check(frames.right.maxX == 1102, "does not reserve space for the deleted settings button")
        check(frames.left.width > 0 && frames.right.width > 0, "keeps usable lyric lanes on a notched MacBook")

        let coveredLeftLane = OverlayLaneGeometry.frames(
            screenFrame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            auxiliaryTopLeftArea: leftSafeArea,
            auxiliaryTopRightArea: rightSafeArea,
            statusItemX: 1300,
            foregroundMenuMaxX: 700,
            menuBarHeight: 32
        )
        check(coveredLeftLane.left.width == 0, "hides the left lyric lane when foreground menus fill its safe area")

        let hiddenStatusItem = OverlayLaneGeometry.frames(
            screenFrame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            auxiliaryTopLeftArea: leftSafeArea,
            auxiliaryTopRightArea: rightSafeArea,
            statusItemX: 8,
            foregroundMenuMaxX: nil,
            menuBarHeight: 32
        )
        check(hiddenStatusItem.right.width == frames.right.width, "ignores a culled off-screen status item coordinate")

        let fallback = OverlayLaneGeometry.frames(
            screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            statusItemX: 1200,
            foregroundMenuMaxX: nil,
            menuBarHeight: 24
        )
        check(fallback.left.maxX <= 720 && fallback.right.minX >= 720, "separates fallback lanes on a non-notched display")
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
        let request = LRCLIBLyricsSource().request(for: track)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        check(components?.path == "/api/search", "uses LRCLIB search")
        check(components?.queryItems == [
            URLQueryItem(name: "track_name", value: "Song"),
            URLQueryItem(name: "artist_name", value: "Artist")
        ], "sends only official LRCLIB search parameters")
        check(request.timeoutInterval == 8, "uses an eight-second LRCLIB timeout")
        check(request.value(forHTTPHeaderField: "User-Agent") == "MenuBarLyrics/0.1 (macOS)", "sets the LRCLIB user agent")
    }

    private static func testLRCLIBFixtures() {
        let source = LRCLIBLyricsSource()
        let loveScenario = SpotifyTrack(name: "LOVE SCENARIO", artist: "iKON", album: "Return", duration: 209)
        let conflicting = lrclibJSON([
            ("LOVE SCENARIO", "iKON", "Return", 209, "[00:01.00]사랑을 했다 우리가 만나"),
            ("LOVE SCENARIO", "iKON", "RETURN -KR EDITION-", 217, "[00:01.00]恋に落ちた僕たちは")
        ])
        check((try! source.parse(conflicting, for: loveScenario)).isEmpty, "rejects ambiguous Kana/Hangul LRCLIB versions")

        let conflictOutsideMatching = lrclibJSON([
            ("LOVE SCENARIO", "iKON", "Return", 209, "[00:01.00]사랑을 했다 우리가 만나"),
            ("Unrelated", "Someone Else", "Elsewhere", 180, "[00:01.00]恋に落ちた僕たちは")
        ])
        check((try! source.parse(conflictOutsideMatching, for: loveScenario)).isEmpty, "checks script conflicts across every usable LRCLIB candidate")

        let fairyTale = SpotifyTrack(name: "童话", artist: "光良", album: "童话", duration: 241)
        let fairyTaleSearch = lrclibJSON([
            ("童话镇", "陈一发儿", "童话镇", 241, "[00:01.00]错误歌词"),
            ("童话", "光良", "童话", 241, "[00:01.00]忘了有多久")
        ])
        check((try! source.parse(fairyTaleSearch, for: fairyTale)) == [LyricLine(time: 1, text: "忘了有多久")], "selects the matching 童话 synced lyrics")

        let gangnam = SpotifyTrack(name: "Gangnam Style", artist: "PSY", album: "Psy 6 (Six Rules), Pt. 1", duration: 219)
        let gangnamSearch = lrclibJSON([
            ("Gangnam Style (Live)", "PSY", "Live", 219, "[00:01.00]Everybody dance"),
            ("Gangnam Style", "PSY", "Psy 6 (Six Rules), Pt. 1", 219, "[00:01.00]오빤 강남스타일")
        ])
        check((try! source.parse(gangnamSearch, for: gangnam)) == [LyricLine(time: 1, text: "오빤 강남스타일")], "selects the matching Gangnam Style synced lyrics")

        let japanese = SpotifyTrack(name: "Lemon Japanese ver.", artist: "Kenshi Yonezu", album: "BOOTLEG", duration: 256)
        let japaneseOnly = lrclibJSON([("Lemon Japanese ver.", "Kenshi Yonezu", "BOOTLEG", 256, "[00:01.00]夢ならばどれほどよかったでしょう")])
        check(!(try! source.parse(japaneseOnly, for: japanese)).isEmpty, "keeps explicitly marked Japanese LRCLIB lyrics")

        let romanizedJapanese = lrclibJSON([
            ("Lemon Japanese ver.", "Kenshi Yonezu", "BOOTLEG", 256, "[00:01.00]夢ならばどれほどよかったでしょう"),
            ("Unrelated", "Someone Else", "Elsewhere", 180, "[00:01.00]This is romanized text")
        ])
        check(!(try! source.parse(romanizedJapanese, for: japanese)).isEmpty, "does not treat Kana plus romanized lyrics as a script conflict")

        let unmarkedJapanese = SpotifyTrack(name: "Lemon", artist: "Kenshi Yonezu", album: "BOOTLEG", duration: 256)
        let unmarkedJapaneseOnly = lrclibJSON([("Lemon", "Kenshi Yonezu", "BOOTLEG", 256, "[00:01.00]夢ならばどれほどよかったでしょう")])
        check((try! source.parse(unmarkedJapaneseOnly, for: unmarkedJapanese)).isEmpty, "rejects Kana-dominant lyrics for unmarked Latin Spotify metadata")

        let koreanOnly = lrclibJSON([("Gangnam Style", "PSY", "Psy 6", 219, "[00:01.00]오빤 강남스타일")])
        check(!(try! source.parse(koreanOnly, for: gangnam)).isEmpty, "keeps a single Korean LRCLIB candidate")

        let latin = SpotifyTrack(name: "Hello", artist: "Adele", album: "25", duration: 200)
        let latinOnly = lrclibJSON([("Hello", "Adele", "25", 200, "[00:01.00]Hello from the other side")])
        check(!(try! source.parse(latinOnly, for: latin)).isEmpty, "keeps normal Latin lyrics")

        let tied = lrclibJSON([
            ("Song", "Artist", "Album", 198, "[00:01.00]First"),
            ("Song (feat. Guest)", "Artist", "Other Album", 202, "[00:01.00]Second")
        ])
        let tiedTrack = SpotifyTrack(name: "Song", artist: "Artist", album: "Album", duration: 200)
        check((try! source.parse(tied, for: tiedTrack)).isEmpty, "rejects distinct equal-scoring LRCLIB candidates")

        let duplicate = lrclibJSON([
            ("Hello!", "ADELE", "25", 200, "[00:01.00]Hello from the other side"),
            ("hello", "Adele", "Deluxe", 201, "[00:01.00]Hello from the other side")
        ])
        check(!(try! source.parse(duplicate, for: latin)).isEmpty, "deduplicates candidates with equivalent normalized metadata")

        let duplicateConflict = lrclibJSON([
            ("LOVE SCENARIO Japanese ver.", "iKON", "Return", 209, "[00:01.00]사랑을 했다 우리가 만나"),
            ("love scenario japanese ver", "IKON", "Return JP", 209, "[00:01.00]恋に落ちた僕たちは")
        ])
        let markedDuplicate = SpotifyTrack(name: "LOVE SCENARIO Japanese ver.", artist: "iKON", album: "Return JP", duration: 209)
        check((try! source.parse(duplicateConflict, for: markedDuplicate)).isEmpty, "checks duplicate metadata for Kana/Hangul conflict before deduplication")
    }

    private static func lrclibJSON(_ rows: [(String, String, String, Double, String)]) -> Data {
        try! JSONSerialization.data(withJSONObject: rows.enumerated().map {
            ["id": $0.offset + 1, "trackName": $0.element.0, "artistName": $0.element.1,
             "albumName": $0.element.2, "duration": $0.element.3, "syncedLyrics": $0.element.4]
        })
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

    private static func testQQMusicRequests() {
        let source = QQMusicLyricsSource()
        let track = SpotifyTrack(name: "稻香", artist: "周杰伦", album: "魔杰座", duration: 223)
        check(source.searchQueries(for: track) == ["稻香 周杰伦", "稻香"], "falls back from title and artist to title-only QQ search")
        let search = try! source.searchRequest(query: "稻香 周杰伦")
        check(search.httpMethod == "POST", "uses POST for QQ Music search")
        check(search.timeoutInterval == 8, "uses an eight-second QQ Music timeout")
        check(search.value(forHTTPHeaderField: "Referer") == "https://c.y.qq.com/", "sets the QQ Music referer")

        let body = try! JSONSerialization.jsonObject(with: search.httpBody!) as! [String: Any]
        let request = body["req_1"] as! [String: Any]
        check(request["module"] as? String == "music.search.SearchCgiService", "uses the QQ Music search service")
        check(request["method"] as? String == "DoSearchForQQMusicDesktop", "uses the QQ Music desktop search method")

        let lyric = source.lyricRequest(songMID: "003aAYrm3GE0Ac")
        let items = URLComponents(url: lyric.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(items?.contains(URLQueryItem(name: "songmid", value: "003aAYrm3GE0Ac")) == true, "sends the QQ Music song MID")
        check(lyric.timeoutInterval == 8, "uses an eight-second QQ lyric timeout")

        let smartbox = source.smartboxRequest(query: "稻香 周杰伦")
        let smartboxItems = URLComponents(url: smartbox.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(smartboxItems?.contains(URLQueryItem(name: "key", value: "稻香 周杰伦")) == true, "sends the QQ Smartbox query")

        let details = source.songDetailsRequest(songMID: "003aAYrm3GE0Ac")
        let detailsItems = URLComponents(url: details.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(detailsItems?.contains(URLQueryItem(name: "songmid", value: "003aAYrm3GE0Ac")) == true, "requests QQ song details by MID")
    }

    private static func testQQMusicFixtures() {
        let source = QQMusicLyricsSource()
        let track = SpotifyTrack(name: "稻香", artist: "周杰伦", album: "魔杰座", duration: 223)
        let search = try! JSONSerialization.data(withJSONObject: [
            "req_1": ["data": ["body": ["song": ["list": [
                ["id": "string-id", "mid": "wrong", "title": "稻香 (Live)", "singer": [["name": "其他歌手"]], "interval": 223],
                ["mid": "correct", "title": "稻香", "singer": [["name": "周杰伦"]], "interval": 223]
            ]]]]]
        ])
        check((try! source.matchingSongMID(in: search, for: track)) == "correct", "selects the matching QQ Music candidate")

        let wrongArtist = try! JSONSerialization.data(withJSONObject: [
            "req_1": ["data": ["body": ["song": ["list": [
                ["id": 1, "mid": "wrong", "title": "稻香", "singer": [["name": "其他歌手"]], "interval": 223]
            ]]]]]
        ])
        check((try! source.matchingSongMID(in: wrongArtist, for: track)) == nil, "rejects a QQ Music cover by another artist")

        let smartbox = try! JSONSerialization.data(withJSONObject: [
            "data": ["song": ["itemlist": [
                ["mid": "correct", "name": "稻香", "singer": "周杰伦"],
                ["mid": "cover", "name": "稻香", "singer": "其他歌手"]
            ]]]
        ])
        check((try! source.matchingSmartboxSongMID(in: smartbox, for: track)) == "correct", "selects the matching QQ Smartbox candidate")

        func details(interval: Int) -> Data {
            let payload = try! JSONSerialization.data(withJSONObject: [
                "code": 0,
                "data": [["mid": "correct", "title": "稻香", "singer": [["name": "周杰伦"]], "interval": interval]]
            ])
            return Data("getOneSongInfoCallback(\(String(decoding: payload, as: UTF8.self)))".utf8)
        }
        check((try! source.validatedSongMID(in: details(interval: 223), for: track)) == "correct", "validates QQ Smartbox results with real duration")
        check((try! source.validatedSongMID(in: details(interval: 260), for: track)) == nil, "rejects a same-title QQ recording with a different duration")

        let lrc = "[00:01.00]对这个世界如果你有太多的抱怨\n[00:03.00]跌倒了就不敢继续往前走"
        let payload = try! JSONSerialization.data(withJSONObject: [
            "code": 0,
            "lyric": Data(lrc.utf8).base64EncodedString()
        ])
        let jsonp = Data("MusicJsonCallback_lrc(\(String(decoding: payload, as: UTF8.self)))".utf8)
        check((try! source.parseLyrics(jsonp)) == [
            LyricLine(time: 1, text: "对这个世界如果你有太多的抱怨"),
            LyricLine(time: 3, text: "跌倒了就不敢继续往前走")
        ], "decodes QQ Music JSONP and Base64 line lyrics")
        check((try! source.parseLyrics(Data("not jsonp".utf8))).isEmpty, "rejects malformed QQ Music lyric responses")
    }

    private static func testKugouRequests() {
        let source = KugouLyricsSource()
        let track = SpotifyTrack(name: "大鱼", artist: "周深", album: "大鱼", duration: 313)
        let search = source.songSearchRequest(for: track)
        let searchItems = URLComponents(url: search.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(search.url?.host == "mobilecdn.kugou.com", "uses the Kugou song search host")
        check(searchItems?.contains(URLQueryItem(name: "keyword", value: "大鱼 周深")) == true, "sends title and artist to Kugou search")
        check(search.timeoutInterval == 8, "uses an eight-second Kugou search timeout")

        let lyrics = source.lyricsSearchRequest(keyword: "大鱼 周深", duration: 313, hash: "hash")
        let lyricItems = URLComponents(url: lyrics.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(lyricItems?.contains(URLQueryItem(name: "duration", value: "313000")) == true, "sends milliseconds to Kugou lyric search")
        check(lyricItems?.contains(URLQueryItem(name: "hash", value: "hash")) == true, "sends the Kugou song hash")

        let download = source.downloadRequest(id: "123", accessKey: "key")
        let downloadItems = URLComponents(url: download.url!, resolvingAgainstBaseURL: false)?.queryItems
        check(downloadItems?.contains(URLQueryItem(name: "id", value: "123")) == true, "sends the Kugou lyric id")
        check(downloadItems?.contains(URLQueryItem(name: "accesskey", value: "key")) == true, "sends the Kugou lyric access key")
    }

    private static func testKugouFixtures() {
        let source = KugouLyricsSource()
        let track = SpotifyTrack(name: "大鱼", artist: "周深", album: "大鱼", duration: 313)
        let songSearch = try! JSONSerialization.data(withJSONObject: [
            "status": 1,
            "data": ["info": [
                ["hash": "cover", "songname": "大鱼", "singername": "其他歌手", "duration": 313],
                ["hash": "near", "songname": "大鱼", "singername": "周深", "duration": 317],
                ["hash": "parent", "songname": "大鱼 (Live)", "singername": "周深", "duration": 313, "group": [
                    ["hash": "correct", "songname": "大鱼", "singername": "周深", "duration": 313]
                ]]
            ]]
        ])
        check((try! source.matchingSong(in: songSearch, for: track))?.hash == "correct", "selects the closest matching nested Kugou song")

        let duet = SpotifyTrack(name: "打上花火", artist: "DAOKO × 米津玄師", album: "打上花火", duration: 289)
        let duetSearch = try! JSONSerialization.data(withJSONObject: [
            "status": 1,
            "data": ["info": [["hash": "duet", "songname": "打上花火", "singername": "DAOKO、米津玄師", "duration": 289]]]
        ])
        check((try! source.matchingSong(in: duetSearch, for: duet))?.hash == "duet", "matches Kugou ideographic artist separators")

        let lyricSearch = try! JSONSerialization.data(withJSONObject: [
            "status": 200,
            "candidates": [
                ["id": "wrong", "accesskey": "wrong", "singer": "其他歌手", "song": "大鱼", "duration": 313_000],
                ["id": "right", "accesskey": "key", "singer": "周深", "song": "大鱼", "duration": 313_000],
                ["id": "duplicate", "accesskey": "other", "singer": "周深", "song": "大鱼", "duration": 313_100]
            ]
        ])
        check((try! source.matchingLyrics(in: lyricSearch, for: track))?.id == "right", "deduplicates equivalent Kugou lyric uploads")

        let boundaryTrack = SpotifyTrack(name: "AB", artist: "C", album: "Album", duration: 200)
        let boundarySearch = try! JSONSerialization.data(withJSONObject: [
            "status": 200,
            "candidates": [
                ["id": "collision", "accesskey": "wrong", "singer": "BC", "song": "A", "duration": 200_000],
                ["id": "boundary", "accesskey": "right", "singer": "C", "song": "AB", "duration": 200_000]
            ]
        ])
        check((try! source.matchingLyrics(in: boundarySearch, for: boundaryTrack))?.id == "boundary", "keeps title and artist boundaries in Kugou deduplication")

        let encrypted = "a3JjMTjbGsglTQAlwOOCgBP9uCbNoutBagJEl2A0I5z41FTPAPHgqs2PfysRGjnCJwDTNZGBQSLYlGQSt5BRePV0t+kYV7+E9w8oR7sMLx0="
        let krc = try! source.decryptKRC(encrypted)
        check(source.parseKRC(krc) == [
            LyricLine(time: 1, text: "你好"),
            LyricLine(time: 3, text: "世界")
        ], "decrypts and parses Kugou KRC line lyrics")
        check((try? source.decryptKRC("not base64")) == nil, "rejects malformed Kugou KRC content")
        check((try? source.decryptKRC(Data("nopepayload".utf8).base64EncodedString())) == nil, "rejects a malformed Kugou KRC header")
        check((try? source.decryptKRC(Data("krc1truncated".utf8).base64EncodedString())) == nil, "rejects truncated Kugou KRC data")
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

    private static func testQQMusicLive() async {
        let source = QQMusicLyricsSource()
        let representatives = [
            SpotifyTrack(name: "稻香", artist: "周杰伦", album: "魔杰座", duration: 223),
            SpotifyTrack(name: "如愿", artist: "王菲", album: "如愿", duration: 265),
            SpotifyTrack(name: "光年之外", artist: "G.E.M.邓紫棋", album: "光年之外", duration: 235)
        ]
        for track in representatives {
            let lines = try! await source.syncedLyrics(for: track)
            print("QQ Music live \(track.name): \(lines.count) lines")
            check(!lines.isEmpty, "fetches live QQ Music lyrics for \(track.name)")
        }
    }

    private static func testLRCLIBLive() async {
        let source = LRCLIBLyricsSource()
        do {
            let loveScenario = SpotifyTrack(name: "LOVE SCENARIO", artist: "iKON", album: "Return", duration: 209)
            let conflictLines = try await source.syncedLyrics(for: loveScenario)
            print("LRCLIB live LOVE SCENARIO: \(conflictLines.count) lines")
            check(conflictLines.isEmpty, "rejects a live LRCLIB LOVE SCENARIO conflict window")
        } catch {
            fputs("LRCLIB live LOVE SCENARIO skipped after network failure: \(error)\n", stderr)
        }

        let expected = [
            SpotifyTrack(name: "童话", artist: "光良", album: "童话", duration: 242),
            SpotifyTrack(name: "Gangnam Style", artist: "PSY", album: "Psy 6 (Six Rules), Pt. 1", duration: 219)
        ]
        for track in expected {
            do {
                let lines = try await source.syncedLyrics(for: track)
                print("LRCLIB live \(track.name): \(lines.count) lines")
                check(!lines.isEmpty, "selects live LRCLIB lyrics for \(track.name)")
            } catch {
                fputs("LRCLIB live \(track.name) skipped after network failure: \(error)\n", stderr)
            }
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
            (track("演员", "薛之謙", 261), candidate("演员", ["薛之谦"], 261_000)),
            (track("说散就散", "JC", 231), candidate("说散就散", ["JC 陈咏桐"], 231_000)),
            (track("Hello!", "Adele"), candidate("hello", ["ADELE"])),
            (track("Beyonce", "Beyonce"), candidate("Beyonce", ["Beyonce"])),
            (track("Song (feat. Guest)", "Artist, Guest"), candidate("Song", ["Artist", "Guest"])),
            (track("Song(feat.Live)"), candidate("Song")),
            (track("Song - 2011 Remaster"), candidate("Song (Remastered 2011)")),
            (track("Song", "Artist & Guest"), candidate("Song", ["Artist", "Guest"])),
            (track("Song", "Artist & Guest"), candidate("Song", ["Guest", "Artist"])),
            (track("打上花火", "DAOKO × 米津玄師", 289), candidate("打上花火", ["DAOKO", "米津玄師"], 289_000)),
            (track("打上花火", "DAOKO × 米津玄師", 289), candidate("打上花火", ["DAOKO、米津玄師"], 289_000)),
            (track("Cancion", "Jose"), candidate("Canción", ["José"])),
            (track("夜に駆ける", "YOASOBI", 262), candidate("夜に駆ける", ["YOASOBI"], 262_000)),
            (track("봄날", "BTS", 274), candidate("봄날", ["BTS"], 274_000)),
            (track("Song"), candidate("Song", ["Artist"], 208_000))
        ]
        for (source, result) in accepted {
            check(TrackMatcher.score(source, candidate: result) >= TrackMatcher.acceptanceThreshold, "accepts \(source.name) by \(source.artist)")
        }

        let rejected: [(SpotifyTrack, TrackMatcher.Candidate)] = [
            (track("Song", "AB, C"), candidate("Song", ["A", "BC"])),
            (track("Song", "AC/DC"), candidate("Song", ["DC"])),
            (track("Song", "Earth, Wind & Fire"), candidate("Song", ["Fire"])),
            (track("Song", "Artist, Guest"), candidate("Song", ["Guest"])),
            (track("Song", "Artist feat. Guest"), candidate("Song (feat. Guest)", ["Artist"])),
            (track("Song", "Artist, Guest"), candidate("Song", ["Guest", "Other"])),
            (track("成都", "赵雷", 328), candidate("成都", ["其他歌手"], 328_020)),
            (track("Hotel California", "Eagles", 391), candidate("Hotel California", ["Eagles Tribute"], 391_000)),
            (track("乾", "Artist", 200), candidate("幹", ["Artist"], 200_000)),
            (track("成都", "赵雷", 328), candidate("成都", ["赵雷"], 340_001)),
            (track("Song"), candidate("Song", ["Artist"], 208_001)),
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
