import Foundation

enum PlayerSource: String, CaseIterable, Equatable, Sendable {
    case auto = "Auto Detect (Recommended)"
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case netEaseMusic = "NetEase Cloud Music"
    case qqMusic = "QQ Music"
    case sodaMusic = "Soda Music"

    static let detectable: [PlayerSource] = [.spotify, .appleMusic, .netEaseMusic, .qqMusic, .sodaMusic]

    var bundleIdentifier: String? {
        switch self {
        case .auto: nil
        case .spotify: "com.spotify.client"
        case .appleMusic: "com.apple.Music"
        case .netEaseMusic: "com.netease.163music"
        case .qqMusic: "com.tencent.QQMusicMac"
        case .sodaMusic: "com.soda.music"
        }
    }

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        L10n.text(rawValue, language: language)
    }
}

final class AutoDetectAdapter: @unchecked Sendable, MusicPlayerAdapter {
    let source = PlayerSource.auto

    private let adapters: [(PlayerSource, any MusicPlayerAdapter)]
    private let lock = NSLock()
    private var selectedSource: PlayerSource?
    private var observations: [PlayerSource: Observation] = [:]

    struct Observation {
        let snapshot: MusicPlayerSnapshot
        let sampledAt: TimeInterval
        let activityAt: TimeInterval?
        let playbackFreshAt: TimeInterval?
    }

    convenience init() {
        self.init(adapters: [
            (.spotify, SpotifyAdapter()),
            (.appleMusic, AppleMusicAdapter()),
            (.netEaseMusic, NetEaseMusicAdapter()),
            (.qqMusic, MediaRemotePlayerAdapter(source: .qqMusic)),
            (.sodaMusic, MediaRemotePlayerAdapter(source: .sodaMusic))
        ])
    }

    init(adapters: [(PlayerSource, any MusicPlayerAdapter)]) {
        self.adapters = adapters
    }

    func snapshot() async -> MusicPlayerSnapshot {
        var candidates: [(PlayerSource, MusicPlayerSnapshot)] = []
        for (source, adapter) in adapters {
            candidates.append((source, await adapter.snapshot()))
        }
        let now = ProcessInfo.processInfo.systemUptime
        let selection = lock.withLock {
            for candidate in candidates {
                observations[candidate.0] = Self.observation(
                    previous: observations[candidate.0],
                    snapshot: candidate.1,
                    at: now
                )
            }
            let activity = observations.mapValues(\.activityAt)
            let freshPlaying = Set<PlayerSource>(observations.compactMap { source, observation in
                guard case .playing = observation.snapshot,
                      let freshAt = observation.playbackFreshAt,
                      now - freshAt <= 3 else { return nil }
                return source
            })
            let result = Self.select(candidates, current: selectedSource, activity: activity, freshPlaying: freshPlaying)
            selectedSource = result.source
            return result
        }
        return selection.snapshot
    }

    func shutdown() {
        adapters.forEach { $0.1.shutdown() }
    }

    static func select(
        _ candidates: [(source: PlayerSource, snapshot: MusicPlayerSnapshot)],
        current: PlayerSource?,
        activity: [PlayerSource: TimeInterval?] = [:],
        freshPlaying: Set<PlayerSource>? = nil
    ) -> (source: PlayerSource?, snapshot: MusicPlayerSnapshot) {
        let playing = candidates.filter {
            guard case .playing = $0.snapshot else { return false }
            return freshPlaying?.contains($0.source) ?? true
        }
        if let freshest = playing.max(by: {
            (activity[$0.source] ?? nil) ?? -.infinity < (activity[$1.source] ?? nil) ?? -.infinity
        }), let freshestAt = activity[freshest.source] ?? nil {
            let tied = playing.filter { (activity[$0.source] ?? nil) == freshestAt }
            if let retained = tied.first(where: { $0.source == current }) { return retained }
            return freshest
        }
        if let retained = playing.first(where: { $0.source == current }) { return retained }
        if let first = playing.first { return first }

        let paused = candidates.filter { if case .paused = $0.snapshot { true } else { false } }
        if let retained = paused.first(where: { $0.source == current }) { return retained }
        if let first = paused.first { return first }
        if candidates.contains(where: {
            if case .playing = $0.snapshot { return true }
            return $0.snapshot == .stopped
        }) { return (nil, .stopped) }
        return (nil, candidates.contains { $0.snapshot == .unavailable } ? .unavailable : .closed)
    }

    static func observation(
        previous: Observation?,
        snapshot: MusicPlayerSnapshot,
        at time: TimeInterval
    ) -> Observation {
        guard let track = snapshot.currentTrack else {
            return Observation(snapshot: snapshot, sampledAt: time, activityAt: nil, playbackFreshAt: nil)
        }
        guard let previous, let oldTrack = previous.snapshot.currentTrack else {
            return Observation(snapshot: snapshot, sampledAt: time, activityAt: time, playbackFreshAt: time)
        }
        let changedTrack = oldTrack.observationIdentity != track.observationIdentity
        let changedState = oldTrack.playbackState != track.playbackState
        let elapsed = max(0, time - previous.sampledAt)
        let moved = track.playbackPosition > oldTrack.playbackPosition + min(0.25, elapsed / 2)
        let positionDelta = track.playbackPosition - oldTrack.playbackPosition
        let seeked = abs(positionDelta) > 0.25 && abs(positionDelta - elapsed) > 2
        return Observation(
            snapshot: snapshot,
            sampledAt: time,
            activityAt: changedTrack || changedState || seeked ? time : previous.activityAt,
            playbackFreshAt: changedTrack || changedState || moved ? time : previous.playbackFreshAt
        )
    }
}

enum PlayerPlaybackState: String, Equatable, Sendable {
    case playing
    case paused
    case stopped
}

enum TrackVersionHint: String, Equatable, Sendable {
    case live
    case remix
    case acoustic
    case remastered
    case soundtrack
    case cover
    case deluxe
    case featuredArtist

    static func detect(title: String, album: String) -> [Self]? {
        let value = "\(title) \(album)".lowercased()
        let markers: [(Self, [String])] = [
            (.live, [#"\blive\b"#]),
            (.remix, [#"\bremix\b"#]),
            (.acoustic, [#"\bacoustic\b"#]),
            (.remastered, [#"\bremaster(?:ed)?\b"#]),
            (.soundtrack, [#"\bsoundtrack\b"#, #"\bost\b"#]),
            (.cover, [#"\bcover\b"#]),
            (.deluxe, [#"\bdeluxe\b"#]),
            (.featuredArtist, [#"\bfeat\.?\b"#, #"\bft\.?\b"#, #"\bfeaturing\b"#])
        ]
        let hints = markers.compactMap { hint, patterns in
            patterns.contains { value.range(of: $0, options: .regularExpression) != nil } ? hint : nil
        }
        return hints.isEmpty ? nil : hints
    }
}

struct NowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let playbackPosition: TimeInterval
    let playbackState: PlayerPlaybackState
    let playerSource: PlayerSource
    let nativeTrackID: String?
    let isrc: String?
    let versionHints: [TrackVersionHint]?

    var spotifyTrack: SpotifyTrack {
        SpotifyTrack(name: title, artist: artist, album: album, duration: duration)
    }

    var observationIdentity: String {
        [playerSource.rawValue, nativeTrackID ?? "", title, artist, album, String(duration)]
            .joined(separator: "\u{1F}")
    }
}

enum MusicPlayerSnapshot: Equatable, Sendable {
    case closed
    case unavailable
    case stopped
    case playing(NowPlayingTrack)
    case paused(NowPlayingTrack)

    var isAvailable: Bool {
        switch self {
        case .stopped, .playing, .paused: true
        case .closed, .unavailable: false
        }
    }

    var currentTrack: NowPlayingTrack? {
        switch self {
        case let .playing(track), let .paused(track): track
        case .closed, .unavailable, .stopped: nil
        }
    }

    var playbackState: PlayerPlaybackState? { currentTrack?.playbackState }
    var playbackPosition: TimeInterval? { currentTrack?.playbackPosition }
}

protocol MusicPlayerAdapter: Sendable {
    var source: PlayerSource { get }
    func snapshot() async -> MusicPlayerSnapshot
    func observeTrackChanges() -> AsyncStream<NowPlayingTrack?>
    func shutdown()
}

extension MusicPlayerAdapter {
    func isAvailable() async -> Bool { await snapshot().isAvailable }
    func currentTrack() async -> NowPlayingTrack? { await snapshot().currentTrack }
    func playbackState() async -> PlayerPlaybackState? { await snapshot().playbackState }
    func playbackPosition() async -> TimeInterval? { await snapshot().playbackPosition }
    func shutdown() {}

    func observeTrackChanges() -> AsyncStream<NowPlayingTrack?> {
        AsyncStream { continuation in
            let task = Task {
                var previous: NowPlayingTrack?
                while !Task.isCancelled {
                    let current = await snapshot().currentTrack
                    if current?.observationIdentity != previous?.observationIdentity {
                        continuation.yield(current)
                        previous = current
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct SpotifyAdapter: MusicPlayerAdapter {
    let source = PlayerSource.spotify

    func snapshot() async -> MusicPlayerSnapshot {
        Self.snapshot(from: await SpotifyReader.read())
    }

    static func snapshot(from state: SpotifyState) -> MusicPlayerSnapshot {
        switch state {
        case .closed:
            return .closed
        case .unavailable:
            return .unavailable
        case let .playing(track, position):
            return .playing(nowPlaying(track, position: position, state: .playing))
        case let .paused(track, position):
            return .paused(nowPlaying(track, position: position, state: .paused))
        }
    }

    private static func nowPlaying(
        _ track: SpotifyTrack,
        position: TimeInterval,
        state: PlayerPlaybackState
    ) -> NowPlayingTrack {
        NowPlayingTrack(
            title: track.name,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            playbackPosition: position,
            playbackState: state,
            playerSource: .spotify,
            nativeTrackID: nil,
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: track.name, album: track.album)
        )
    }
}
