import Foundation

/// Prefix ranges retain real token timing; the renderer supplies actual layout widths.
public struct LyricHighlight: Equatable, Sendable {
    public let prefixBefore: String
    public let prefixThrough: String
    public let fraction: CGFloat

    public func progress(in text: String, measure: (String) -> CGFloat) -> CGFloat {
        let width = measure(text)
        guard width > 0 else { return 0 }
        let before = measure(prefixBefore), through = measure(prefixThrough)
        return max(0, min(1, (before + max(0, through - before) * fraction) / width))
    }
}

public struct LyricMoment: Equatable, Sendable {
    public let text: String
    public let progress: CGFloat
    public let identity: Int
    public let timingFidelity: TimingFidelity
    public let highlight: LyricHighlight?
}

public enum LyricClock {
    public static func moment(at position: TimeInterval, in document: TimedLyricDocument) -> LyricMoment? {
        moment(at: position + document.metadata.lyricOffset, in: document.lines)
    }

    public static func moment(at position: TimeInterval, in lines: [LyricLine]) -> LyricMoment? {
        guard !lines.isEmpty, position.isFinite else { return nil }
        var low = 0, high = lines.count - 1
        var match: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position { match = mid; low = mid + 1 } else { high = mid - 1 }
        }
        guard let index = match else { return nil }
        let line = lines[index]
        if !line.segments.isEmpty && !line.segments.contains(where: \.synthetic) {
            var prefix = ""
            for segment in line.segments {
                let through = prefix + segment.text
                if position < segment.endTime {
                    let fraction = CGFloat(max(0, min(1, (position - segment.time) / (segment.endTime - segment.time))))
                    let highlight = LyricHighlight(prefixBefore: prefix, prefixThrough: through, fraction: fraction)
                    return LyricMoment(text: line.text, progress: highlight.progress(in: line.text) { CGFloat($0.count) },
                                       identity: index, timingFidelity: line.timingFidelity, highlight: highlight)
                }
                prefix = through
            }
            return LyricMoment(text: line.text, progress: 1, identity: index, timingFidelity: line.timingFidelity,
                               highlight: LyricHighlight(prefixBefore: line.text, prefixThrough: line.text, fraction: 1))
        }
        guard let end = line.endTime, !line.endTimeIsEstimated else {
            // Missing genuine timing is static; line-start gaps are not vocal durations.
            return LyricMoment(text: line.text, progress: 1, identity: index, timingFidelity: line.timingFidelity, highlight: nil)
        }
        let progress = CGFloat(max(0, min(1, (position - line.time) / (end - line.time))))
        return LyricMoment(text: line.text, progress: progress, identity: index, timingFidelity: .lineWithEnd, highlight: nil)
    }

    public static func currentLine(at position: TimeInterval, in lines: [LyricLine]) -> String? {
        moment(at: position, in: lines)?.text
    }
}
