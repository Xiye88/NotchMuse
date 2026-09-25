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
    private var newestTimestamp: String?

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

        guard Self.hasUsableMetadata(event) else { return [] }
        if let timestamp = event.timestamp, let newestTimestamp, timestamp < newestTimestamp { return [] }
        if let timestamp = event.timestamp { newestTimestamp = max(newestTimestamp ?? timestamp, timestamp) }

        let identity = Self.identity(of: event)
        if let committed, Self.identity(of: committed) == identity {
            let stableEvent = Self.updatingPlayback(of: committed, from: event)
            self.committed = stableEvent
            pending = nil
            return [.event(stableEvent)]
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
        if let nativeID = event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue,
           !nativeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["id:\(nativeID)", event.title, event.artist ?? ""]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .joined(separator: "\u{1F}")
        }
        return [event.title, event.artist ?? "", String(Int((event.duration ?? 0).rounded()))]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "\u{1F}")
    }

    mutating func reset() {
        previousInput = nil
        committed = nil
        pending = nil
        newestTimestamp = nil
    }

    private static func hasUsableMetadata(_ event: MediaRemoteEvent) -> Bool {
        !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(event.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func updatingPlayback(of stable: MediaRemoteEvent, from latest: MediaRemoteEvent) -> MediaRemoteEvent {
        MediaRemoteEvent(
            bundleIdentifier: stable.bundleIdentifier,
            parentApplicationBundleIdentifier: stable.parentApplicationBundleIdentifier,
            playing: latest.playing,
            title: stable.title,
            artist: stable.artist,
            album: stable.album,
            duration: stable.duration,
            elapsedTimeNow: latest.elapsedTimeNow,
            timestamp: latest.timestamp,
            uniqueIdentifier: stable.uniqueIdentifier,
            contentItemIdentifier: stable.contentItemIdentifier,
            mediaType: stable.mediaType
        )
    }
}
