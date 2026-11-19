import Foundation

public enum TimingFidelity: String, Equatable, Sendable {
    case word, lineWithEnd, lineStartOnly, estimated
}

public struct LyricSegment: Equatable, Sendable {
    public let time: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let synthetic: Bool

    public init(time: TimeInterval, endTime: TimeInterval, text: String, synthetic: Bool = false) {
        self.time = time
        self.endTime = endTime
        self.text = text
        self.synthetic = synthetic
    }
}

public struct LyricLine: Equatable, Sendable {
    public let time: TimeInterval
    public let text: String
    public let translation: String?
    public let endTime: TimeInterval?
    public let segments: [LyricSegment]
    public let endTimeIsEstimated: Bool

    public init(time: TimeInterval, text: String, translation: String? = nil, endTime: TimeInterval? = nil, segments: [LyricSegment] = [], endTimeIsEstimated: Bool = false) {
        self.time = time
        self.text = text
        self.translation = translation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? translation : nil
        let validEnd = endTime.flatMap { $0.isFinite && $0 > time ? $0 : nil }
        self.endTime = validEnd
        self.endTimeIsEstimated = endTimeIsEstimated
        // Malformed word timing falls back to the line, never to incorrect text ranges.
        let valid = segments.enumerated().allSatisfy { index, segment in
            segment.time.isFinite && segment.endTime.isFinite && segment.time >= time &&
            segment.endTime > segment.time && (validEnd == nil || segment.endTime <= validEnd! + 0.001) &&
            (index == 0 || segment.time >= segments[index - 1].endTime - 0.001)
        }
        self.segments = valid && segments.map(\.text).joined() == text ? segments : []
    }

    public var timingFidelity: TimingFidelity {
        if !segments.isEmpty { return segments.contains(where: \.synthetic) ? .estimated : .word }
        return endTime == nil ? .lineStartOnly : (endTimeIsEstimated ? .estimated : .lineWithEnd)
    }

    public func shifted(by offset: TimeInterval) -> LyricLine {
        LyricLine(time: time + offset, text: text, translation: translation, endTime: endTime.map { $0 + offset },
                  segments: segments.map { LyricSegment(time: $0.time + offset, endTime: $0.endTime + offset, text: $0.text, synthetic: $0.synthetic) }, endTimeIsEstimated: endTimeIsEstimated)
    }
}

public struct LyricsMetadata: Equatable, Sendable {
    public var provider: String?
    public var platformTrackID: String?
    public var isrc: String?
    /// Seconds added to playback position. Applied once by the document clock.
    public var lyricOffset: TimeInterval
    /// Descriptive silence duration; never added as a second offset.
    public var leadingSilence: TimeInterval?

    public init(provider: String? = nil, platformTrackID: String? = nil, isrc: String? = nil,
                lyricOffset: TimeInterval = 0, leadingSilence: TimeInterval? = nil) {
        self.provider = provider
        self.platformTrackID = platformTrackID
        self.isrc = isrc
        self.lyricOffset = lyricOffset.isFinite ? lyricOffset : 0
        self.leadingSilence = leadingSilence
    }
}

public struct TimedLyricDocument: Equatable, Sendable {
    public let lines: [LyricLine]
    public let metadata: LyricsMetadata

    public init(lines: [LyricLine], metadata: LyricsMetadata = LyricsMetadata()) {
        self.lines = lines.filter { $0.time.isFinite }.sorted { $0.time < $1.time }
        self.metadata = metadata
    }

    /// Compatibility with providers returning arrays; bake the document offset in once.
    public var normalizedLines: [LyricLine] { lines.map { $0.shifted(by: -metadata.lyricOffset) } }
    public var timingFidelity: TimingFidelity {
        guard !lines.isEmpty else { return .lineStartOnly }
        if lines.allSatisfy({ $0.timingFidelity == .word }) { return .word }
        if lines.allSatisfy({ $0.endTime != nil }) { return lines.contains(where: \.endTimeIsEstimated) ? .estimated : .lineWithEnd }
        return .lineStartOnly
    }
}

public enum LyricParser {
    public static func parse(_ lrc: String) -> [LyricLine] { parseDocument(lrc).normalizedLines }

    public static func parseDocument(_ lrc: String, provider: String? = nil) -> TimedLyricDocument {
        TimedLyricDocument(lines: lrc.split(whereSeparator: \.isNewline).flatMap(parseLine),
                           metadata: LyricsMetadata(provider: provider, lyricOffset: offset(in: lrc)))
    }

    public static func offset(in text: String) -> TimeInterval {
        let regex = try! NSRegularExpression(pattern: #"(?im)^\s*\[offset:([+-]?\d+(?:\.\d+)?)\]\s*$"#)
        guard let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let range = Range(match.range(at: 1), in: text), let milliseconds = Double(text[range]),
              milliseconds.isFinite else { return 0 }
        return milliseconds / 1000
    }

    /// KRC token times are relative to the line; YRC token times are absolute milliseconds.
    public static func parseKRC(_ text: String) -> [LyricLine] { parseTimedText(text, tokenPattern: #"<(\d+),(\d+),\d+>"#, relative: true) }
    public static func parseYRC(_ text: String) -> [LyricLine] { parseTimedText(text, tokenPattern: #"\((\d+),(\d+),\d+\)"#, relative: false) }

    private static func parseTimedText(_ text: String, tokenPattern: String, relative: Bool) -> [LyricLine] {
        let lineRegex = try! NSRegularExpression(pattern: #"^\[(\d+),(\d+)\](.*)$"#)
        let tokenRegex = try! NSRegularExpression(pattern: tokenPattern)
        let lines: [LyricLine] = text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = String(raw)
            guard let match = lineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let startRange = Range(match.range(at: 1), in: line), let durationRange = Range(match.range(at: 2), in: line),
                  let bodyRange = Range(match.range(at: 3), in: line),
                  let start = Double(line[startRange]), let duration = Double(line[durationRange]) else { return nil }
            let body = String(line[bodyRange])
            let tokens = tokenRegex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            var segments: [LyricSegment] = []
            for (index, token) in tokens.enumerated() {
                guard let timeRange = Range(token.range(at: 1), in: body), let lengthRange = Range(token.range(at: 2), in: body),
                      let time = Double(body[timeRange]), let length = Double(body[lengthRange]),
                      let textRange = Range(NSRange(location: token.range.upperBound,
                                                   length: (index + 1 < tokens.count ? tokens[index + 1].range.location : (body as NSString).length) - token.range.upperBound), in: body) else { continue }
                var tokenText = String(body[textRange])
                if index == 0 { tokenText = tokenText.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression) }
                if index == tokens.count - 1 { tokenText = tokenText.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }
                segments.append(LyricSegment(time: (relative ? start + time : time) / 1000,
                                             endTime: ((relative ? start + time : time) + length) / 1000, text: tokenText))
            }
            let content = tokenRegex.stringByReplacingMatches(in: body, range: NSRange(body.startIndex..., in: body), withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return LyricLine(time: start / 1000, text: content, endTime: (start + duration) / 1000, segments: segments)
        }
        return TimedLyricDocument(lines: lines, metadata: LyricsMetadata(lyricOffset: offset(in: text))).normalizedLines
    }

    private static let enhancedTokenRegex = try! NSRegularExpression(pattern: #"<(\d+:\d+(?:\.\d+)?)>"#)

    private static func parseLine(_ rawLine: Substring) -> [LyricLine] {
        var rest = String(rawLine)
        var times: [TimeInterval] = []
        while rest.first == "[" {
            guard let close = rest.firstIndex(of: "]") else { break }
            let tag = String(rest[rest.index(after: rest.startIndex)..<close])
            if let time = parseTime(tag) { times.append(time) }
            rest = String(rest[rest.index(after: close)...])
        }
        guard !times.isEmpty else { return [] }
        let body = rest.trimmingCharacters(in: .whitespaces)
        let tokens = enhancedTokenRegex.matches(in: body, range: NSRange(body.startIndex..., in: body))
        if tokens.isEmpty {
            guard !body.isEmpty else { return [] }
            return times.map { LyricLine(time: $0, text: body) }
        }
        let cleaned = enhancedTokenRegex.stringByReplacingMatches(in: body, range: NSRange(body.startIndex..., in: body), withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return [] }
        if times.count == 1 {
            let lineStart = times[0]
            var parsedTokens: [(time: TimeInterval, range: NSRange)] = []
            for match in tokens {
                if let r = Range(match.range(at: 1), in: body), let t = parseTime(String(body[r])) {
                    parsedTokens.append((t, match.range))
                }
            }
            var segments: [LyricSegment] = []
            var lineEnd: TimeInterval? = nil
            for (index, token) in parsedTokens.enumerated() {
                let textStart = token.range.upperBound
                let textEnd = index + 1 < parsedTokens.count ? parsedTokens[index + 1].range.location : (body as NSString).length
                if textEnd <= textStart {
                    if index == parsedTokens.count - 1 && token.time > lineStart { lineEnd = token.time }
                    continue
                }
                guard let textRange = Range(NSRange(location: textStart, length: textEnd - textStart), in: body) else { continue }
                var tokenText = String(body[textRange])
                if segments.isEmpty { tokenText = tokenText.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression) }
                let nextTime: TimeInterval? = index + 1 < parsedTokens.count ? parsedTokens[index + 1].time : nil
                if let nextTime, nextTime > token.time {
                    if index + 1 == parsedTokens.count - 1 {
                        tokenText = tokenText.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
                    }
                    segments.append(LyricSegment(time: token.time, endTime: nextTime, text: tokenText))
                    lineEnd = max(lineEnd ?? nextTime, nextTime)
                }
            }
            return [LyricLine(time: lineStart, text: cleaned, endTime: lineEnd, segments: segments)]
        }
        return times.map { LyricLine(time: $0, text: cleaned) }
    }

    private static func parseTime(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]),
              minutes.isFinite, seconds.isFinite, minutes >= 0, seconds >= 0, seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }
}
