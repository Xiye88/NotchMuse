import Foundation

enum PlayerSource: String, CaseIterable, Equatable, Sendable {
    case auto = "Auto Detect (Recommended)"
    case allNowPlaying = "All macOS Now Playing Apps"

    // Mainstream
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case netEaseMusic = "NetEase Cloud Music"
    case qqMusic = "QQ Music"
    case sodaMusic = "Soda Music"
    case kugouMusic = "Kugou Music"
    case youtubeMusic = "YouTube Music"

    // Domestic & Open-Source CN
    case kuwoMusic = "Kuwo Music"
    case miguMusic = "Migu Music"
    case bodianMusic = "Bodian Music"
    case qianqianMusic = "Qianqian Music"
    case lxMusic = "LX Music"
    case yesPlayMusic = "YesPlayMusic"
    case algerMusic = "AlgerMusicPlayer"
    case listen1 = "Listen 1"
    case splayer = "SPlayer"

    // International, Audiophile & NAS
    case tidal = "TIDAL"
    case amazonMusic = "Amazon Music"
    case deezer = "Deezer"
    case qobuz = "Qobuz"
    case plexamp = "Plexamp"
    case cider = "Cider"
    case soundCloud = "SoundCloud"
    case bandcamp = "Bandcamp"
    case swinsian = "Swinsian"
    case vox = "VOX"
    case foobar2000 = "foobar2000"
    case audirvana = "Audirvana"
    case roon = "Roon"
    case pinePlayer = "Pine Player"
    case cog = "Cog"
    case feishin = "Feishin"
    case supersonic = "Supersonic"

    // Manual-Only Video / Media Players (excluded from Auto Detect & All Now Playing)
    case iina = "IINA"
    case vlc = "VLC"
    case bilibili = "Bilibili"

    static let detectable: [PlayerSource] = [
        .spotify, .appleMusic, .netEaseMusic, .qqMusic, .sodaMusic,
        .kugouMusic, .youtubeMusic,
        .kuwoMusic, .miguMusic, .bodianMusic, .qianqianMusic,
        .lxMusic, .yesPlayMusic, .algerMusic, .listen1, .splayer,
        .tidal, .amazonMusic, .deezer, .qobuz, .plexamp,
        .cider, .soundCloud, .bandcamp,
        .swinsian, .vox, .foobar2000, .audirvana, .roon, .pinePlayer, .cog,
        .feishin, .supersonic
    ]

    static let menuGroups: [(title: String?, sources: [PlayerSource])] = [
        (nil, [.auto, .allNowPlaying]),
        ("Mainstream Players", [.spotify, .appleMusic, .youtubeMusic, .netEaseMusic, .qqMusic, .sodaMusic, .kugouMusic]),
        ("Chinese & Open-Source Players", [.kuwoMusic, .miguMusic, .bodianMusic, .qianqianMusic, .lxMusic, .yesPlayMusic, .algerMusic, .listen1, .splayer]),
        ("Global, Audiophile & NAS", [.tidal, .amazonMusic, .deezer, .qobuz, .plexamp, .cider, .soundCloud, .bandcamp, .swinsian, .vox, .foobar2000, .audirvana, .roon, .pinePlayer, .cog, .feishin, .supersonic]),
        ("Video & Media (Manual Only)", [.iina, .vlc, .bilibili])
    ]

    static let browserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "org.mozilla.firefox"
    ]

    static let nonMusicDenylist: Set<String> = [
        "us.zoom.xos",
        "com.apple.FaceTime",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.QuickTimePlayerX",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "Cisco-Systems.Spark",
        "com.apple.podcasts",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan", // Google Meet PWA
        "com.colliderli.iina",
        "org.videolan.vlc",
        "tv.danmaku.bili",
        "com.bilibili.bilibiliPC"
    ]

    var bundleIdentifiers: [String] {
        switch self {
        case .auto, .allNowPlaying: []
        case .spotify: ["com.spotify.client"]
        case .appleMusic: ["com.apple.Music"]
        case .netEaseMusic: ["com.netease.163music"]
        case .qqMusic: ["com.tencent.QQMusicMac"]
        case .sodaMusic: ["com.soda.music"]
        case .kugouMusic: ["com.kugou.mac", "com.kugou.KugouMusic", "com.kugou.mac.KugouMusic"]
        case .youtubeMusic: [
            "com.github.th-ch.youtube-music",
            "app.ytmdesktop.ytmdesktop",
            "com.google.Chrome.app.cinhimbnkkaeohfgghhklpknlkffjgod",
            "com.microsoft.edgemac.app.cinhimbnkkaeohfgghhklpknlkffjgod",
            "com.brave.Browser.app.cinhimbnkkaeohfgghhklpknlkffjgod"
        ]
        case .kuwoMusic: ["cn.kuwo.KuwoMusic", "com.kuwo.mac.KuwoMusic", "cn.kuwo.player"]
        case .miguMusic: ["cn.migu.music", "com.migu.music.mac"]
        case .bodianMusic: ["cn.kuwo.bodian", "com.bodian.music"]
        case .qianqianMusic: ["com.taihe.qianqianmusic", "com.baidu.music"]
        case .lxMusic: ["cn.toside.music.desktop"]
        case .yesPlayMusic: ["com.qier222.yesplaymusic"]
        case .algerMusic: ["com.alger.music", "com.algermusicplayer.app"]
        case .listen1: ["com.listen1.desktop", "com.github.listen1.listen1_desktop"]
        case .splayer: ["com.imsyy.splayer"]
        case .tidal: ["com.tidal.desktop"]
        case .amazonMusic: ["com.amazon.music"]
        case .deezer: ["com.deezer.deezer-desktop"]
        case .qobuz: ["com.qobuz.QobuzDesktop"]
        case .plexamp: ["tv.plex.plexamp"]
        case .cider: ["sh.cider.Cider", "sh.cider.electron", "com.cider.app"]
        case .soundCloud: ["com.soundcloud.desktop", "com.google.Chrome.app.mpnpojknpmmopombnjdcgaaiekajbnjb"]
        case .bandcamp: ["com.bandcamp.desktop"]
        case .swinsian: ["com.swinsian.Swinsian"]
        case .vox: ["com.coppertino.Vox"]
        case .foobar2000: ["com.foobar2000.mac"]
        case .audirvana: ["com.audirvana.Audirvana-Studio", "com.audirvana.Audirvana-Origin", "com.audirvana.Audirvana"]
        case .roon: ["com.roon.Roon"]
        case .pinePlayer: ["com.digibird.PinePlayer"]
        case .cog: ["org.cogx.cog"]
        case .feishin: ["org.jeffvli.feishin"]
        case .supersonic: ["io.github.dweymouth.supersonic"]
        case .iina: ["com.colliderli.iina"]
        case .vlc: ["org.videolan.vlc"]
        case .bilibili: ["tv.danmaku.bili", "com.bilibili.bilibiliPC"]
        }
    }

    var isVideoOrRelaxedDuration: Bool {
        switch self {
        case .youtubeMusic, .soundCloud, .bilibili, .iina, .vlc, .allNowPlaying: true
        default: false
        }
    }

    var bundleIdentifier: String? {
        bundleIdentifiers.first
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
        let reader = SharedMediaRemoteReader.shared
        let built: [(PlayerSource, any MusicPlayerAdapter)] = PlayerSource.detectable.map { source in
            switch source {
            case .spotify: (source, SpotifyAdapter())
            case .appleMusic: (source, AppleMusicAdapter())
            case .netEaseMusic: (source, NetEaseMusicAdapter())
            default: (source, MediaRemotePlayerAdapter(source: source, sharedReader: reader))
            }
        }
        self.init(adapters: built)
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
        SpotifyTrack(
            name: title,
            artist: artist,
            album: album,
            duration: duration,
            nativeTrackID: nativeTrackID,
            relaxedDurationMatching: playerSource.isVideoOrRelaxedDuration
        )
    }

    var observationIdentity: String {
        [playerSource.rawValue, nativeTrackID ?? "", isrc?.uppercased() ?? "", title, artist, album, String(duration)]
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
            nativeTrackID: track.nativeTrackID,
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: track.name, album: track.album)
        )
    }
}
