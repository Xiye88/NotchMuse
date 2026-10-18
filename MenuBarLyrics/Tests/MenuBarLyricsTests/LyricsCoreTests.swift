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
        XCTAssertEqual(LyricClock.moment(at: 10, in: lines)?.progress, 0.375)
        XCTAssertEqual(LyricClock.currentLine(at: 3.2, in: lines), "Three")
    }

    func testExplicitEndHoldsAcrossInstrumentalGap() {
        let lines = [LyricLine(time: 10, text: "123456", endTime: 12), LyricLine(time: 17, text: "Next")]
        XCTAssertEqual(LyricClock.moment(at: 12, in: lines)?.progress, 1)
        XCTAssertEqual(LyricClock.moment(at: 16.999, in: lines)?.progress, 1)
        XCTAssertEqual(LyricClock.moment(at: 17, in: lines)?.identity, 1)
    }

    func testUnevenWordsAndRest() {
        let line = LyricLine(time: 10, text: "AB", endTime: 12, segments: [
            LyricSegment(time: 10, endTime: 10.2, text: "A"), LyricSegment(time: 11, endTime: 12, text: "B")
        ])
        XCTAssertEqual(LyricClock.moment(at: 10.5, in: [line])?.highlight?.fraction, 0)
        XCTAssertEqual(LyricClock.moment(at: 11.5, in: [line])?.highlight?.fraction, 0.5)
        XCTAssertEqual(LyricClock.moment(at: 14, in: [line])?.progress, 1)
    }

    func testEstimatedTimingKeepsSourceSwitches() {
        let lines = [LyricLine(time: 10, text: "Hello"), LyricLine(time: 70, text: "Next")]
        XCTAssertEqual(LyricClock.moment(at: 18, in: lines)?.progress, 1)
        XCTAssertEqual(LyricClock.moment(at: 18, in: lines)?.timingFidelity, .estimated)
        XCTAssertEqual(LyricClock.moment(at: 69.9, in: lines)?.identity, 0)
        XCTAssertEqual(LyricClock.moment(at: 70, in: lines)?.identity, 1)
    }

    func testOffsetNormalizedOnce() {
        let document = LyricParser.parseDocument("[offset:500]\n[00:10]A\n[00:12]B")
        XCTAssertEqual(document.metadata.lyricOffset, 0.5)
        XCTAssertEqual(LyricClock.moment(at: 10.5, in: document)?.progress, 0.5)
        XCTAssertEqual(LyricClock.moment(at: 10.5, in: document), LyricClock.moment(at: 10.5, in: document.normalizedLines))
    }

}
