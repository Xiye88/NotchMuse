import AppKit
import Foundation

final class NetEaseMusicAdapter: @unchecked Sendable, MusicPlayerAdapter {
    static let bundleIdentifier = NetEaseEventConverger.bundleIdentifier

    let source = PlayerSource.netEaseMusic

    private let bridge: MediaRemoteBridge?
    private let isRunning: @Sendable () -> Bool
    private let lock = NSLock()
    private var current: MusicPlayerSnapshot = .unavailable
    private var currentUpdatedAt: TimeInterval?
    private var lastPositionRefreshAt: TimeInterval?
    private var converger = NetEaseEventConverger()
    private var started = false
    private var stopped = false
    private var restartCount = 0
    private var lastRunning = false

    convenience init() {
        self.init(
            bridge: try? MediaRemoteBridge.bundled(),
            isRunning: {
                !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
            }
        )
    }

    init(bridge: MediaRemoteBridge?, isRunning: @escaping @Sendable () -> Bool) {
        self.bridge = bridge
        self.isRunning = isRunning
    }

    func snapshot() async -> MusicPlayerSnapshot {
        let running = isRunning()
        let now = ProcessInfo.processInfo.systemUptime
        let action = lock.withLock { () -> (connect: Bool, refresh: Bool, position: Bool) in
            let relaunched = running && !lastRunning
            lastRunning = running
            guard running else {
                current = .stopped
                lastPositionRefreshAt = nil
                return (false, false, false)
            }
            guard !stopped, bridge != nil else { return (false, false, false) }
            if !started {
                started = true
                lastPositionRefreshAt = now
                return (true, false, false)
            }
            let refreshPosition = Self.shouldRefreshPosition(last: lastPositionRefreshAt, now: now)
            if refreshPosition { lastPositionRefreshAt = now }
            return (false, relaunched, refreshPosition && !relaunched)
        }

        guard running else { return .closed }
        if action.connect {
            await connect()
        } else if action.refresh {
            await refresh()
        } else if action.position {
            await refreshPosition()
        }
        return lock.withLock {
            Self.advanced(current, since: currentUpdatedAt, now: ProcessInfo.processInfo.systemUptime)
        }
    }

    func shutdown() {
        lock.withLock { stopped = true }
        bridge?.shutdown()
    }

    static func snapshot(from event: MediaRemoteEvent?, isRunning: Bool) -> MusicPlayerSnapshot {
        guard isRunning else { return .closed }
        guard let event, event.bundleIdentifier == bundleIdentifier else { return .stopped }
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
            playerSource: .netEaseMusic,
            nativeTrackID: event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue,
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: event.title, album: event.album ?? "")
        )
        return state == .playing ? .playing(track) : .paused(track)
    }

    static func advanced(
        _ snapshot: MusicPlayerSnapshot,
        since updatedAt: TimeInterval?,
        now: TimeInterval
    ) -> MusicPlayerSnapshot {
        guard let updatedAt, case let .playing(track) = snapshot else { return snapshot }
        let advancedPosition = track.playbackPosition + max(0, now - updatedAt)
        let position = track.duration > 0 ? min(track.duration, advancedPosition) : advancedPosition
        return .playing(NowPlayingTrack(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            playbackPosition: position,
            playbackState: track.playbackState,
            playerSource: track.playerSource,
            nativeTrackID: track.nativeTrackID,
            isrc: track.isrc,
            versionHints: track.versionHints
        ))
    }

    static func shouldRefreshPosition(last: TimeInterval?, now: TimeInterval) -> Bool {
        guard let last else { return true }
        return now - last >= 2
    }

    private func connect() async {
        guard let bridge else {
            lock.withLock { current = .unavailable }
            return
        }
        do {
            let initial = try await Task.detached { [weak self] () -> MediaRemoteEvent? in
                guard let self else { return nil }
                try bridge.healthCheck()
                let event = try? bridge.get()
                try self.startStream()
                return event
            }.value
            lock.withLock {
                current = Self.snapshot(from: initial, isRunning: isRunning())
                currentUpdatedAt = ProcessInfo.processInfo.systemUptime
            }
        } catch {
            lock.withLock { current = .unavailable }
        }
    }

    private func refresh() async {
        guard let bridge else { return }
        let event = await Task.detached { try? bridge.get() }.value
        lock.withLock {
            current = Self.snapshot(from: event, isRunning: isRunning())
            currentUpdatedAt = ProcessInfo.processInfo.systemUptime
        }
    }

    private func refreshPosition() async {
        guard let bridge else { return }
        guard let event = await Task.detached(operation: { try? bridge.get() }).value else { return }
        receive(event)
    }

    private func startStream() throws {
        guard let bridge else { return }
        try bridge.startStream(
            onEvent: { [weak self] event in self?.receive(event) },
            onFailure: { [weak self] _ in self?.recoverStreamOnce() }
        )
    }

    private func receive(_ event: MediaRemoteEvent) {
        let updates = lock.withLock {
            converger.consume(event, at: ProcessInfo.processInfo.systemUptime)
        }
        apply(updates)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.flushConverger()
        }
    }

    private func flushConverger() {
        let updates = lock.withLock {
            converger.flush(at: ProcessInfo.processInfo.systemUptime)
        }
        apply(updates)
    }

    private func apply(_ updates: [NetEaseConvergenceUpdate]) {
        guard let last = updates.last else { return }
        lock.withLock {
            switch last {
            case let .event(event):
#if DEBUG
                print("[NetEase] track=\(event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue ?? "-") title=\(event.title) artist=\(event.artist ?? "-") timestamp=\(event.timestamp ?? "-")")
#endif
                current = Self.snapshot(from: event, isRunning: isRunning())
                currentUpdatedAt = ProcessInfo.processInfo.systemUptime
            case .clear:
                current = isRunning() ? .stopped : .closed
                currentUpdatedAt = nil
            }
        }
    }

    private func recoverStreamOnce() {
        let shouldRestart = lock.withLock { () -> Bool in
            guard !stopped, restartCount == 0 else {
                current = .unavailable
                return false
            }
            restartCount += 1
            return true
        }
        guard shouldRestart else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            do {
                try self.startStream()
            } catch {
                self.lock.withLock { self.current = .unavailable }
            }
        }
    }
}
