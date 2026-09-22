import AppKit
import Foundation

enum PlayerSource: String, CaseIterable, Equatable, Sendable {
    case auto = "Auto Detect (Recommended)"
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case netEaseMusic = "NetEase Cloud Music"

    static let detectable: [PlayerSource] = [.spotify, .appleMusic, .netEaseMusic]

    var bundleIdentifier: String? {
        switch self {
        case .auto: nil
        case .spotify: "com.spotify.client"
        case .appleMusic: "com.apple.Music"
        case .netEaseMusic: "com.netease.163music"
        }
    }

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        self == .netEaseMusic ? L10n.text(rawValue, language: language) : rawValue
    }
}

final class AutoDetectAdapter: @unchecked Sendable, MusicPlayerAdapter {
    let source = PlayerSource.auto

    private let adapters: [(PlayerSource, any MusicPlayerAdapter)]
    private let isRunning: @Sendable (String) -> Bool
    private let lock = NSLock()
    private var selectedSource: PlayerSource?

    convenience init() {
        self.init(
            adapters: [
                (.spotify, SpotifyAdapter()),
                (.appleMusic, AppleMusicAdapter()),
                (.netEaseMusic, NetEaseMusicAdapter())
            ],
            isRunning: { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
        )
    }

    init(
        adapters: [(PlayerSource, any MusicPlayerAdapter)],
        isRunning: @escaping @Sendable (String) -> Bool
    ) {
        self.adapters = adapters
        self.isRunning = isRunning
    }

    func snapshot() async -> MusicPlayerSnapshot {
        var candidates: [(PlayerSource, MusicPlayerSnapshot)] = []
        for (source, adapter) in adapters {
            guard let bundleIdentifier = source.bundleIdentifier, isRunning(bundleIdentifier) else {
                candidates.append((source, .closed))
                continue
            }
            candidates.append((source, await adapter.snapshot()))
        }
        let current = lock.withLock { selectedSource }
        let selection = Self.select(candidates, current: current)
        lock.withLock { selectedSource = selection.source }
        return selection.snapshot
    }

    func shutdown() {
        adapters.forEach { $0.1.shutdown() }
    }

    static func select(
        _ candidates: [(source: PlayerSource, snapshot: MusicPlayerSnapshot)],
        current: PlayerSource?
    ) -> (source: PlayerSource?, snapshot: MusicPlayerSnapshot) {
        for matches in [
            { if case .playing = $0 { true } else { false } },
            { if case .paused = $0 { true } else { false } },
            { if case .stopped = $0 { true } else { false } }
        ] as [(MusicPlayerSnapshot) -> Bool] {
            let matches = candidates.filter { matches($0.snapshot) }
            if let retained = matches.first(where: { $0.source == current }) { return retained }
            if let first = matches.first { return first }
        }
        return (nil, candidates.contains { $0.snapshot == .unavailable } ? .unavailable : .closed)
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
