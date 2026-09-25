import XCTest
import LyricsCore

final class LyricsCoreTests: XCTestCase {
    func testParsesTimestampedAndRepeatedLines() {
        XCTAssertEqual(LyricParser.parse("[00:01.50]Hello\n[00:03.00]World"), [
            LyricLine(time: 1.5, text: "Hello"),
            LyricLine(time: 3.0, text: "World")
        ])
        XCTAssertEqual(LyricParser.parse("[00:01.00][00:02.00]Again"), [
            LyricLine(time: 1, text: "Again"),
            LyricLine(time: 2, text: "Again")
        ])
    }

    func testTracksLyricClockProgress() {
        let lines = [
            LyricLine(time: 1, text: "One"),
            LyricLine(time: 3, text: "Three"),
            LyricLine(time: 7, text: "Seven")
        ]

        XCTAssertNil(LyricClock.moment(at: 0.5, in: lines))
        XCTAssertEqual(LyricClock.moment(at: 1, in: lines)?.progress, 0)
        XCTAssertEqual(LyricClock.moment(at: 2, in: lines)?.progress, 0.5)
        XCTAssertEqual(LyricClock.moment(at: 3, in: lines)?.progress, 0)
        XCTAssertEqual(LyricClock.moment(at: 10, in: lines)?.progress, 1)
        XCTAssertEqual(LyricClock.currentLine(at: 3.2, in: lines), "Three")
    }
}
