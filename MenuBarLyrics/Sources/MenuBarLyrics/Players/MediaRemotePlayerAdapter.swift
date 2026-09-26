import AppKit
import Foundation

final class MediaRemotePlayerAdapter: @unchecked Sendable, MusicPlayerAdapter {
    let source: PlayerSource

    private let bridge: MediaRemoteBridge?
    private let isRunning: @Sendable () -> Bool
    private let lock = NSLock()
    private var didCheckBridge = false

    init(
        source: PlayerSource,
        bridge: MediaRemoteBridge? = try? MediaRemoteBridge.bundled(),
        isRunning: (@Sendable () -> Bool)? = nil
    ) {
        self.source = source
        self.bridge = bridge
        self.isRunning = isRunning ?? {
            guard let bundleIdentifier = source.bundleIdentifier else { return false }
            return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        }
    }

    func snapshot() async -> MusicPlayerSnapshot {
        guard isRunning() else { return .closed }
        guard let bridge else { return .unavailable }
        do {
            let needsHealthCheck = lock.withLock { () -> Bool in
                !didCheckBridge
            }
            if needsHealthCheck {
                try await Task.detached { try bridge.healthCheck() }.value
                lock.withLock { didCheckBridge = true }
            }
            let event = try await Task.detached { try bridge.get() }.value
            return Self.snapshot(from: event, source: source, isRunning: isRunning())
        } catch {
            return .unavailable
        }
    }

    static func snapshot(
        from event: MediaRemoteEvent?,
        source: PlayerSource,
        isRunning: Bool
    ) -> MusicPlayerSnapshot {
        guard isRunning else { return .closed }
        guard let bundleIdentifier = source.bundleIdentifier,
              let event,
              event.bundleIdentifier == bundleIdentifier else { return .stopped }
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !(event.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .stopped
        }

        let state: PlayerPlaybackState = event.playing ? .playing : .paused
        let track = NowPlayingTrack(
            title: event.title,
            artist: event.artist ?? "",
            album: event.album ?? "",
            duration: event.duration ?? 0,
            playbackPosition: event.elapsedTimeNow ?? 0,
            playbackState: state,
            playerSource: source,
            nativeTrackID: event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue,
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: event.title, album: event.album ?? "")
        )
        return event.playing ? .playing(track) : .paused(track)
    }

    func shutdown() {
        bridge?.shutdown()
    }
}
