import AppKit
import Foundation

final class SharedMediaRemoteReader: @unchecked Sendable {
    static let shared = SharedMediaRemoteReader()

    private let bridge: MediaRemoteBridge?
    private let cacheTTL: TimeInterval
    private let lock = NSLock()
    private var didCheckBridge = false
    private var cachedEvent: MediaRemoteEvent?
    private var cachedAt: TimeInterval = -.infinity
    private var lastErrorAt: TimeInterval = -.infinity

    init(
        bridge: MediaRemoteBridge? = try? MediaRemoteBridge.bundled(),
        cacheTTL: TimeInterval = 0.45
    ) {
        self.bridge = bridge
        self.cacheTTL = cacheTTL
    }

    var isAvailable: Bool { bridge != nil }

    func currentEvent() async throws -> MediaRemoteEvent? {
        guard let bridge else { throw MediaRemoteBridgeError.resourcesMissing("MediaRemoteBridge") }
        let now = ProcessInfo.processInfo.systemUptime
        let cached: (valid: Bool, event: MediaRemoteEvent?, needsHealthCheck: Bool) = lock.withLock {
            if now - cachedAt <= cacheTTL {
                return (true, cachedEvent, false)
            }
            return (false, nil, !didCheckBridge)
        }
        if cached.valid {
            return cached.event
        }
        if cached.needsHealthCheck {
            try await Task.detached { try bridge.healthCheck() }.value
            lock.withLock { didCheckBridge = true }
        }
        let event = try await Task.detached { try bridge.get() }.value
        lock.withLock {
            cachedEvent = event
            cachedAt = ProcessInfo.processInfo.systemUptime
        }
        return event
    }

    func invalidateCache() {
        lock.withLock {
            cachedEvent = nil
            cachedAt = -.infinity
        }
    }

    func shutdown() {
        invalidateCache()
        bridge?.shutdown()
    }
}

enum MediaRemoteMetadataSanitizer {
    struct SanitizedMetadata: Equatable, Sendable {
        let title: String
        let artist: String
        let album: String
    }

    private static let trailingSitePatterns = [
        #"\s*[-–—|]\s*YouTube Music\s*$"#,
        #"\s*[-–—|]\s*YouTube\s*$"#
    ]

    private static let videoNoisePatterns = [
        #"\s*[\(\[【]\s*(?:Official\s+)?(?:Music\s+)?(?:Video|MV|Audio|Lyric\s+Video|Lyrics|Visualizer|HD|4K|Live\s+Video)\s*[\)\]】]"#,
        #"\s*【\s*(?:官方\s*)?(?:MV|完整版|高清|纯享版|歌词版)\s*】"#
    ]

    private static let nonMusicKeywords = [
        "zoom meeting", "google meet", "microsoft teams", "netflix", "twitch"
    ]

    static func sanitize(
        title rawTitle: String,
        artist rawArtist: String?,
        album rawAlbum: String?,
        isBrowserOrYouTube: Bool
    ) -> SanitizedMetadata? {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var artist = (rawArtist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let album = (rawAlbum ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return nil }

        if isBrowserOrYouTube {
            for pattern in trailingSitePatterns {
                title = title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
            for pattern in videoNoisePatterns {
                title = title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)

            if artist.lowercased().hasSuffix(" - topic") {
                artist = String(artist.dropLast(" - topic".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if artist.hasSuffix("VEVO") && artist.count > 4 {
                artist = String(artist.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Handle "Artist - Song" packed into title when artist is empty (e.g. Kugou / browser tabs)
        if artist.isEmpty, let split = splitArtistTitle(title) {
            artist = split.artist
            title = split.title
        } else if isBrowserOrYouTube, !artist.isEmpty {
            // Strip redundant "<artist> - " prefix from YouTube MV titles
            for separator in [" - ", " — ", " – "] {
                let prefix = artist + separator
                if title.lowercased().hasPrefix(prefix.lowercased()) && title.count > prefix.count {
                    title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !artist.isEmpty else { return nil }
        return SanitizedMetadata(title: title, artist: artist, album: album)
    }

    static func isLikelyNonMusicBrowserEvent(_ event: MediaRemoteEvent) -> Bool {
        if let duration = event.duration, duration > 900 {
            return true
        }
        let haystack = "\(event.title) \(event.artist ?? "") \(event.album ?? "")".lowercased()
        if nonMusicKeywords.contains(where: { haystack.contains($0) }) {
            return true
        }
        return false
    }

    private static func splitArtistTitle(_ value: String) -> (artist: String, title: String)? {
        for separator in [" - ", " — ", " – "] {
            let parts = value.components(separatedBy: separator)
            if parts.count == 2 {
                let lhs = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let rhs = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !lhs.isEmpty && !rhs.isEmpty {
                    return (lhs, rhs)
                }
            }
        }
        return nil
    }
}

final class MediaRemotePlayerAdapter: @unchecked Sendable, MusicPlayerAdapter {
    let source: PlayerSource

    private let reader: SharedMediaRemoteReader
    private let ownsReader: Bool
    private let isRunning: @Sendable () -> Bool

    init(
        source: PlayerSource,
        sharedReader: SharedMediaRemoteReader = .shared,
        isRunning: (@Sendable () -> Bool)? = nil
    ) {
        self.source = source
        self.reader = sharedReader
        self.ownsReader = false
        self.isRunning = isRunning ?? Self.defaultIsRunning(for: source)
    }

    convenience init(
        source: PlayerSource,
        bridge: MediaRemoteBridge?,
        isRunning: (@Sendable () -> Bool)? = nil
    ) {
        self.init(
            source: source,
            sharedReader: SharedMediaRemoteReader(bridge: bridge, cacheTTL: 0),
            isRunning: isRunning
        )
    }

    private static func defaultIsRunning(for source: PlayerSource) -> @Sendable () -> Bool {
        if source == .allNowPlaying {
            return { true }
        }
        var candidates = Set(source.bundleIdentifiers)
        if source == .youtubeMusic {
            candidates.formUnion(PlayerSource.browserBundleIdentifiers)
        }
        let targetBundles = candidates
        return {
            targetBundles.contains { bundleID in
                !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
            }
        }
    }

    func snapshot() async -> MusicPlayerSnapshot {
        guard isRunning() else { return .closed }
        guard reader.isAvailable else { return .unavailable }
        do {
            let event = try await reader.currentEvent()
            return Self.snapshot(from: event, source: source, isRunning: isRunning())
        } catch {
            return .unavailable
        }
    }

    static func matches(event: MediaRemoteEvent, source: PlayerSource) -> Bool {
        let bundle = event.bundleIdentifier
        let parent = event.parentApplicationBundleIdentifier

        if source == .allNowPlaying {
            if PlayerSource.nonMusicDenylist.contains(bundle) { return false }
            if let parent, PlayerSource.nonMusicDenylist.contains(parent) { return false }
            if PlayerSource.browserBundleIdentifiers.contains(bundle),
               MediaRemoteMetadataSanitizer.isLikelyNonMusicBrowserEvent(event) {
                return false
            }
            return true
        }

        if source.bundleIdentifiers.contains(bundle) {
            return true
        }
        if let parent, source.bundleIdentifiers.contains(parent) {
            return true
        }

        if source == .youtubeMusic {
            let isBrowser = PlayerSource.browserBundleIdentifiers.contains(bundle)
                || (parent.map { PlayerSource.browserBundleIdentifiers.contains($0) } ?? false)
            guard isBrowser else { return false }
            if MediaRemoteMetadataSanitizer.isLikelyNonMusicBrowserEvent(event) {
                return false
            }
            // Accept browser media if it looks like YouTube Music / music playback (non-empty artist or "Artist - Title" or YouTube hint)
            let artist = (event.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = "\(title) \(artist) \(event.album ?? "")".lowercased()
            if lower.contains("youtube") || !artist.isEmpty || title.contains(" - ") {
                return true
            }
        }
        return false
    }

    static func snapshot(
        from event: MediaRemoteEvent?,
        source: PlayerSource,
        isRunning: Bool
    ) -> MusicPlayerSnapshot {
        guard isRunning else { return .closed }
        guard let event, matches(event: event, source: source) else { return .stopped }

        let isBrowserOrYT = source == .youtubeMusic
            || PlayerSource.browserBundleIdentifiers.contains(event.bundleIdentifier)
            || (event.parentApplicationBundleIdentifier.map { PlayerSource.browserBundleIdentifiers.contains($0) } ?? false)

        guard let sanitized = MediaRemoteMetadataSanitizer.sanitize(
            title: event.title,
            artist: event.artist,
            album: event.album,
            isBrowserOrYouTube: isBrowserOrYT
        ) else {
            return .stopped
        }

        let state: PlayerPlaybackState = event.playing ? .playing : .paused
        let track = NowPlayingTrack(
            title: sanitized.title,
            artist: sanitized.artist,
            album: sanitized.album,
            duration: event.duration ?? 0,
            playbackPosition: event.elapsedTimeNow ?? 0,
            playbackState: state,
            playerSource: source,
            nativeTrackID: event.contentItemIdentifier ?? event.uniqueIdentifier?.rawValue,
            isrc: nil,
            versionHints: TrackVersionHint.detect(title: sanitized.title, album: sanitized.album)
        )
        return event.playing ? .playing(track) : .paused(track)
    }

    func shutdown() {
        if ownsReader {
            reader.shutdown()
        }
    }
}
