import Foundation

enum LyricClock {
    static func currentLine(at position: TimeInterval, in lines: [LyricLine]) -> String? {
        guard !lines.isEmpty else { return nil }

        var low = 0
        var high = lines.count - 1
        var match: LyricLine?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                match = lines[mid]
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return match?.text
    }
}
