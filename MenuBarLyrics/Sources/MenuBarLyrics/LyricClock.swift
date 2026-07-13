import Foundation

struct LyricMoment: Equatable {
    let text: String
    let progress: CGFloat
}

enum LyricClock {
    static func moment(at position: TimeInterval, in lines: [LyricLine]) -> LyricMoment? {
        guard !lines.isEmpty else { return nil }

        var low = 0
        var high = lines.count - 1
        var match: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                match = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        guard let index = match else { return nil }
        let progress = index + 1 < lines.count
            ? CGFloat(max(0, min(1, (position - lines[index].time) / (lines[index + 1].time - lines[index].time))))
            : 1
        return LyricMoment(text: lines[index].text, progress: progress)
    }

    static func currentLine(at position: TimeInterval, in lines: [LyricLine]) -> String? {
        moment(at: position, in: lines)?.text
    }
}
