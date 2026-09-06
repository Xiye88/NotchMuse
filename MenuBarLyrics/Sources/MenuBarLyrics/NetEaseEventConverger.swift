import Foundation

enum NetEaseConvergenceUpdate: Equatable, Sendable {
    case event(MediaRemoteEvent)
    case clear
}

struct NetEaseEventConverger: Sendable {
    static let bundleIdentifier = "com.netease.163music"

    private struct Pending: Sendable {
        let event: MediaRemoteEvent
        let identity: String
        let since: TimeInterval
    }

    private let quietInterval: TimeInterval
    private var previousInput: MediaRemoteEvent?
    private var committed: MediaRemoteEvent?
    private var pending: Pending?

    init(quietInterval: TimeInterval = 0.3) {
        self.quietInterval = quietInterval
    }

    mutating func consume(_ event: MediaRemoteEvent, at time: TimeInterval) -> [NetEaseConvergenceUpdate] {
        guard event != previousInput else { return [] }
        previousInput = event

        guard event.bundleIdentifier == Self.bundleIdentifier else {
            let hadNetEaseState = committed != nil || pending != nil
            committed = nil
            pending = nil
            return hadNetEaseState ? [.clear] : []
        }

        let identity = Self.identity(of: event)
        if let committed, Self.identity(of: committed) == identity {
            self.committed = event
            pending = nil
            return [.event(event)]
        }
        if let pending, pending.identity == identity {
            committed = event
            self.pending = nil
            return [.event(event)]
        }

        pending = Pending(event: event, identity: identity, since: time)
        return []
    }

    mutating func flush(at time: TimeInterval) -> [NetEaseConvergenceUpdate] {
        guard let pending, time - pending.since + 0.000_001 >= quietInterval else { return [] }
        committed = pending.event
        self.pending = nil
        return [.event(pending.event)]
    }

    private static func identity(of event: MediaRemoteEvent) -> String {
        let nativeID = event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue ?? ""
        return [nativeID, event.title, event.artist ?? "", event.album ?? "", String(event.duration ?? 0)]
            .joined(separator: "\u{1F}")
    }
}
