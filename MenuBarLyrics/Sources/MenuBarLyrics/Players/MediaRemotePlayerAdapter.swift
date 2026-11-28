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
    private var artworkOrder: [String] = []
    private var artworkCache: [String: Data] = [:]
    private let maxCachedArtworks = 3

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
        let decodedArtwork: Data? = event.artworkData.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        lock.withLock {
            cachedEvent = event
            cachedAt = ProcessInfo.processInfo.systemUptime
            if let decodedArtwork, !decodedArtwork.isEmpty {
                let key = Self.artworkCacheKey(title: event.title, artist: event.artist ?? "")
                artworkCache[key] = decodedArtwork
                artworkOrder.removeAll { $0 == key }
                artworkOrder.append(key)
                while artworkOrder.count > maxCachedArtworks {
                    let evicted = artworkOrder.removeFirst()
                    artworkCache.removeValue(forKey: evicted)
                }
            }
        }
        return event
    }

    static func artworkCacheKey(title: String, artist: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    func cachedArtworkData(title: String, artist: String) -> Data? {
        let key = Self.artworkCacheKey(title: title, artist: artist)
        return lock.withLock {
            if let exact = artworkCache[key] { return exact }
            let lowerTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !lowerTitle.isEmpty, let matchedKey = artworkOrder.last(where: { $0.hasPrefix(lowerTitle + "|") }) {
                return artworkCache[matchedKey]
            }
            return nil
        }
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
        #"\s*[-–—|•]\s*YouTube Music\s*$"#,
        #"\s*[-–—|•]\s*YouTube\s*$"#,
        #"\s*[-–—|•]\s*Spotify\s*$"#,
        #"\s+(?:on\s+)?Apple Music\s*$"#,
        #"\s*[-–—|•]\s*Apple Music\s*$"#,
        #"\s*[-–—|•]\s*(?:单曲\s*[-–—]\s*)?网易云音乐\s*$"#,
        #"\s*[-–—|•]\s*QQ音乐(?:[-–—].*)?\s*$"#,
        #"\s*\|\s*Listen online for free on SoundCloud\s*$"#,
        #"\s*(?:[-–—|•]|on)\s*SoundCloud\s*$"#,
        #"\s*\|\s*Bandcamp\s*$"#,
        #"\s*[_-]\s*哔哩哔哩[_-]bilibili\s*$"#,
        #"\s*[-–—|•]\s*bilibili\s*$"#
    ]

    private static let videoNoisePatterns = [
        #"\s*[\(\[【（［]\s*(?:Official\s+)?(?:Music\s+)?(?:Video|MV|M/V|Audio|Lyric\s+Video|Lyrics?|Visualizer|Visual|HD|4K|original\s+ver\.?)\s*[\)\]】）］]"#,
        #"\s*[\(\[【（［]\s*(?:(?:官方|華納|华纳|高畫質|高画质|HD|Official)\s*)*(?:MV|完整版|高清|高畫質|纯享版|純享版|歌词版|歌詞版|动态歌词|動態歌詞)\s*[\)\]】）］]"#,
        #"\s*[\(\[【（［][^()\[\]【】（）［］]*(?:官方完整版|高畫質|官方MV|动态歌词|動態歌詞|純享版|纯享版)[^()\[\]【】（）［］]*[\)\]】）］]"#,
        #"\s*[\(\[]\s*(?:from\s+[^)\]]+|Spider-Man:[^)\]]+)\s*[\)\]]"#,
        #"\s+(?:Official\s+Music\s+Video|Official\s+Video|Official\s+MV|Official\s+Audio|MUSIC\s+VIDEO|M/V|MV)\s*$"#
    ]

    private static let channelArtistKeywords = [
        "vevo", "labels", "smtown", "jyp entertainment", "yg entertainment",
        "records", "binmusic", "jvr music", "warner music", "sony music",
        "universal music", "1thek", "youtube channel", "official channel",
        "滚石唱片", "滾石唱片", "杰威尔音乐", "杰威爾音樂", "相信音樂", "相信音乐",
        "華納音樂", "华纳音乐", "福茂唱片", "海蝶音乐", "海蝶音樂"
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

        var artistLooksLikeChannel = false
        if isBrowserOrYouTube {
            for pattern in trailingSitePatterns {
                title = title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
            for _ in 0..<2 {
                for pattern in videoNoisePatterns {
                    title = title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
                }
            }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)

            let lowerArtist = artist.lowercased()
            if lowerArtist.hasSuffix(" - topic") {
                artist = String(artist.dropLast(" - topic".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if artist.hasSuffix("VEVO") && artist.count > 4 {
                artist = String(artist.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                artistLooksLikeChannel = true
            } else if channelArtistKeywords.contains(where: { lowerArtist.contains($0) }) {
                artistLooksLikeChannel = true
            } else if lowerArtist.hasSuffix(" official") && artist.count > 9 {
                artist = String(artist.dropLast(" official".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if artist.isEmpty {
            if let split = splitArtistTitle(title) {
                artist = split.artist
                title = split.title
            }
        } else if isBrowserOrYouTube {
            let expectedArtist = cleanYouTubeArtist(artist)
            let splits = [
                splitArtistTitle(title, matchingArtist: expectedArtist),
                extractBracketedArtistTitle(title),
                extractQuotedArtistTitle(title),
                artistLooksLikeChannel ? splitArtistTitle(title) : nil
            ]
            if let split = splits.compactMap({ $0 }).first(where: {
                artistLooksLikeChannel || sameArtist(expectedArtist, cleanYouTubeArtist($0.artist))
            }) {
                artist = split.artist
                title = split.title
            }

            title = title.trimmingCharacters(in: CharacterSet(charactersIn: "'\"“”‘’ "))
            for pattern in videoNoisePatterns {
                title = title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
            artist = cleanYouTubeArtist(artist)
            let cleanedTitle = cleanYouTubeTitleAndExtractFeature(title)
            title = cleanedTitle.title
            if let featured = cleanedTitle.featured, !artistOverlaps(artist, with: featured) {
                artist = "\(artist), \(featured)"
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

    private static func splitArtistTitle(_ value: String, matchingArtist: String? = nil) -> (artist: String, title: String)? {
        for separator in [" - ", " — ", " – ", " _ "] {
            let parts = value.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }
            let lhs = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if let matchingArtist {
                guard sameArtist(matchingArtist, cleanYouTubeArtist(lhs)) else { continue }
            } else if parts.count != 2 {
                continue
            }
            let rhs = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
            if !lhs.isEmpty && !rhs.isEmpty { return (lhs, rhs) }
        }
        return nil
    }

    private static func sameArtist(_ lhs: String, _ rhs: String) -> Bool {
        let expected = TrackMatcher.artistKeys([lhs]).members
        return !expected.isEmpty && expected == TrackMatcher.artistKeys([rhs]).members
    }

    private static func extractBracketedArtistTitle(_ value: String) -> (artist: String, title: String)? {
        let patterns = [
            #"^(.+?)\s*【([^】]+)】\s*$"#,
            #"^(.+?)\s*「([^」]+)」\s*$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  match.numberOfRanges >= 3,
                  let r1 = Range(match.range(at: 1), in: value),
                  let r2 = Range(match.range(at: 2), in: value) else { continue }
            let lhs = value[r1].trimmingCharacters(in: CharacterSet(charactersIn: " -–—|"))
            let inner = value[r2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !lhs.isEmpty && !inner.isEmpty {
                return (lhs, inner)
            }
        }
        return nil
    }

    private static func extractQuotedArtistTitle(_ value: String) -> (artist: String, title: String)? {
        let patterns = [
            #"^(.+?)\s*(?:-\s*)?'([^']{2,})'\s*$"#,
            #"^(.+?)\s*(?:-\s*)?"([^"]{2,})"\s*$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  match.numberOfRanges >= 3,
                  let r1 = Range(match.range(at: 1), in: value),
                  let r2 = Range(match.range(at: 2), in: value) else { continue }
            let lhs = value[r1].trimmingCharacters(in: CharacterSet(charactersIn: " -–—|"))
            let inner = value[r2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !lhs.isEmpty && !inner.isEmpty {
                return (lhs, inner)
            }
        }
        return nil
    }

    private static func artistOverlaps(_ a: String, with b: String) -> Bool {
        func compact(_ s: String) -> String {
            s.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(String.init).joined()
        }
        let ca = compact(a), cb = compact(b)
        guard !ca.isEmpty, !cb.isEmpty else { return false }
        return ca == cb || cb.contains(ca) || ca.contains(cb)
    }

    private static func cleanYouTubeArtist(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: #"\s*[\(（][^\(\)（）]+[\)）]\s*$"#, with: "", options: .regularExpression)
        if let regex = try? NSRegularExpression(pattern: #"^([\p{Han}·\s]{2,12})\s+[A-Za-z][A-Za-z0-9\s.'-]{1,24}$"#),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r1 = Range(match.range(at: 1), in: value) {
            value = String(value[r1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let regex = try? NSRegularExpression(pattern: #"^([A-Za-z0-9\s.'-]{2,20})\s+[\uAC00-\uD7A3\s]{2,}$"#),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r1 = Range(match.range(at: 1), in: value) {
            value = String(value[r1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanYouTubeTitleAndExtractFeature(_ raw: String) -> (title: String, featured: String?) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var featured: String?
        let featurePatterns = [
            #"\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring)\s+([^\)\]]+)[\)\]]\s*$"#,
            #"\s+(?:feat\.?|ft\.?|featuring)\s+(.+)$"#
        ]
        for pattern in featurePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               match.numberOfRanges >= 2,
               let r1 = Range(match.range(at: 1), in: value),
               let fullRange = Range(match.range(at: 0), in: value) {
                let candidate = String(value[r1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty { featured = candidate }
                value.removeSubrange(fullRange)
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"^([A-Za-z0-9\s.'!?&-]+?)\s*\([\uAC00-\uD7A3\s]+\)\s*$"#),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r1 = Range(match.range(at: 1), in: value) {
            value = String(value[r1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let regex = try? NSRegularExpression(pattern: #"^([\u4E00-\u9FFF\u3040-\u30FF]{2,16})\s+[A-Za-z][A-Za-z0-9\s'’!?.,-]{2,}$"#),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r1 = Range(match.range(at: 1), in: value) {
            let candidate = String(value[r1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                value = candidate
            }
        }
        return (value.trimmingCharacters(in: .whitespacesAndNewlines), featured)
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
            || source == .soundCloud
            || source == .bilibili
            || source == .iina
            || source == .vlc
            || source == .allNowPlaying
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

/// Bounded 3-entry in-memory album artwork cache with non-blocking MediaRemote + Spotify fallback.
@MainActor
final class AlbumArtworkCache {
    static let shared = AlbumArtworkCache()

    private var order: [String] = []
    private var images: [String: NSImage] = [:]
    private var inFlightKeys: Set<String> = []
    private let maxEntries = 3

    func artwork(
        title: String,
        artist: String,
        source: PlayerSource,
        onLoaded: @escaping @MainActor (NSImage?) -> Void
    ) -> NSImage? {
        let key = SharedMediaRemoteReader.artworkCacheKey(title: title, artist: artist)
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let cached = images[key] {
            return cached
        }
        if let rawData = SharedMediaRemoteReader.shared.cachedArtworkData(title: title, artist: artist),
           let image = NSImage(data: rawData) {
            store(image, forKey: key)
            return image
        }
        guard !inFlightKeys.contains(key) else { return nil }
        inFlightKeys.insert(key)

        Task {
            let fetched = await Self.fetchArtworkData(title: title, artist: artist, source: source)
            await MainActor.run {
                self.inFlightKeys.remove(key)
                if let fetched, let image = NSImage(data: fetched) {
                    self.store(image, forKey: key)
                    onLoaded(image)
                }
            }
        }
        return nil
    }

    private func store(_ image: NSImage, forKey key: String) {
        images[key] = image
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > maxEntries {
            let evicted = order.removeFirst()
            images.removeValue(forKey: evicted)
        }
    }

    private static func fetchArtworkData(title: String, artist: String, source: PlayerSource) async -> Data? {
        // 1. Try SharedMediaRemoteReader (covers 36+ players including Soda/NetEase/QQ/YTM/Apple Music)
        if SharedMediaRemoteReader.shared.isAvailable {
            _ = try? await SharedMediaRemoteReader.shared.currentEvent()
            if let data = SharedMediaRemoteReader.shared.cachedArtworkData(title: title, artist: artist) {
                return data
            }
        }
        // 2. Lightweight Spotify AppleScript artwork URL fallback
        if source == .spotify {
            let urlString: String? = await Task.detached(priority: .utility) {
                let script = """
                if application "Spotify" is running then
                  tell application "Spotify"
                    try
                      return artwork url of current track as string
                    end try
                  end tell
                end if
                return ""
                """
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return (out?.isEmpty == false) ? out : nil
                } catch {
                    return nil
                }
            }.value
            if let urlString, let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.timeoutInterval = 4
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   (response as? HTTPURLResponse)?.statusCode == 200,
                   !data.isEmpty {
                    return data
                }
            }
        }
        return nil
    }
}
