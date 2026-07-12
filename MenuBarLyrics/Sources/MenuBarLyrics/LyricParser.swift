import Foundation

struct LyricLine: Equatable {
    let time: TimeInterval
    let text: String
}

enum LyricParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        lrc.split(whereSeparator: \.isNewline)
            .flatMap(parseLine)
            .sorted { $0.time < $1.time }
    }

    private static func parseLine(_ rawLine: Substring) -> [LyricLine] {
        var rest = String(rawLine)
        var times: [TimeInterval] = []

        while rest.first == "[" {
            guard let close = rest.firstIndex(of: "]") else { break }
            let tag = String(rest[rest.index(after: rest.startIndex)..<close])
            if let time = parseTime(tag) {
                times.append(time)
            }
            rest = String(rest[rest.index(after: close)...])
        }

        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !times.isEmpty, !text.isEmpty else { return [] }
        return times.map { LyricLine(time: $0, text: text) }
    }

    private static func parseTime(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
}
