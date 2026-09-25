import Foundation

struct ScrollState {
    private static let initialDelay: TimeInterval = 1.2
    private var startedAt = ProcessInfo.processInfo.systemUptime

    mutating func reset(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        startedAt = time
    }

    func offset(
        contentWidth: CGFloat,
        viewportWidth: CGFloat,
        speedMultiplier: CGFloat = 1,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> CGFloat {
        let distance = max(0, contentWidth - viewportWidth)
        guard distance > 0 else { return 0 }

        let speed: CGFloat = 28 * max(0.1, speedMultiplier)
        let elapsed = max(0, time - startedAt - Self.initialDelay)
        return min(distance, CGFloat(elapsed) * speed)
    }

    func isFinished(
        contentWidth: CGFloat,
        viewportWidth: CGFloat,
        speedMultiplier: CGFloat = 1,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        let distance = max(0, contentWidth - viewportWidth)
        guard distance > 0 else { return true }
        return offset(
            contentWidth: contentWidth,
            viewportWidth: viewportWidth,
            speedMultiplier: speedMultiplier,
            at: time
        ) >= distance
    }
}
