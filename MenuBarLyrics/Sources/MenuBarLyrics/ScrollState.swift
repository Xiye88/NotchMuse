import Foundation

struct ScrollState {
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
        let pause: TimeInterval = 0.9
        let travelTime = TimeInterval(distance / speed)
        let cycle = 2 * (pause + travelTime)
        let phase = max(0, time - startedAt).truncatingRemainder(dividingBy: cycle)

        if phase < pause {
            return 0
        }
        if phase < pause + travelTime {
            return CGFloat(phase - pause) * speed
        }
        if phase < 2 * pause + travelTime {
            return distance
        }
        return distance - CGFloat(phase - 2 * pause - travelTime) * speed
    }
}
