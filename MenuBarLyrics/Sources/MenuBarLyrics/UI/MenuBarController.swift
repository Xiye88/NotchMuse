import AppKit
import OSLog
import Foundation
import LyricsCore

enum PlayerFeedback {
    case checking
    case connected
    case notRunning
    case unavailable

    func menuTitle(for source: PlayerSource, language: AppLanguage = AppPreferences.language) -> String {
        switch self {
        case .checking: return L10n.format("%@: Checking...", source.displayName(language: language), language: language)
        case .connected: return L10n.format("%@: Connected", source.displayName(language: language), language: language)
        case .notRunning: return L10n.format("%@: Not Running", source.displayName(language: language), language: language)
        case .unavailable: return L10n.format("%@: Connection Error", source.displayName(language: language), language: language)
        }
    }
}

enum LyricsFeedback {
    case waiting
    case searching
    case available
    case notFound
    case timeout
    case networkFailure

    func menuTitle(for source: PlayerSource) -> String {
        switch self {
        case .waiting: return L10n.format("Lyrics: Waiting for %@", source.displayName())
        case .searching: return L10n.text("Lyrics: Searching...")
        case .available: return L10n.text("Lyrics: Available")
        case .notFound: return L10n.text("Lyrics: Not Found")
        case .timeout: return L10n.text("Lyrics: Search Timed Out")
        case .networkFailure: return L10n.text("Lyrics: Network Error")
        }
    }

    var displayText: String {
        switch self {
        case .waiting: return L10n.text("Waiting for Spotify")
        case .searching: return L10n.text("Searching lyrics...")
        case .available: return L10n.text("Lyrics available")
        case .notFound: return AppPreferences.missingLyricsAnimationStyle.shortBarCaption()
        case .timeout: return L10n.text("Lyrics search timed out")
        case .networkFailure: return L10n.text("Lyrics network unavailable")
        }
    }
}

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem = {
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        let autosaveName = isPreview ? "\(Bundle.main.bundleIdentifier ?? "app.notchmuse.mac.preview").StatusItem" : "NotchMuseStatusItem"
        let item = NSStatusBar.system.statusItem(withLength: isPreview ? NSStatusItem.variableLength : NSStatusItem.squareLength)
        item.autosaveName = autosaveName
        item.isVisible = true
        return item
    }()
    private let overlay = OverlayLyricsWindow()
    private let lyricsClient = LyricsClient()
    private var player: any MusicPlayerAdapter = SpotifyAdapter()
    private var displayMode = AppPreferences.displayMode
    private var position = AppPreferences.position
    private var notchStyle = AppPreferences.notchStyle
    private var settingsWindowController: SettingsWindowController?
    private let displayModeMenu = NSMenu()
    private let displayModeMenuItem = NSMenuItem(title: L10n.text("Display Mode"), action: nil, keyEquivalent: "")
    private let positionMenu = NSMenu()
    private let positionMenuItem = NSMenuItem(title: L10n.text("Status Bar Position"), action: nil, keyEquivalent: "")
    private let timingOffsetMenu = NSMenu()
    private let timingOffsetMenuItem = NSMenuItem(title: L10n.text("Lyric Timing Offset"), action: nil, keyEquivalent: "")
    private let moveLyricsMenuItem = NSMenuItem(title: L10n.text("Move Lyrics"), action: nil, keyEquivalent: "")
    private let resetPositionMenuItem = NSMenuItem(title: L10n.text("Reset Position"), action: nil, keyEquivalent: "")
    private let announcementMenuItem = NSMenuItem(title: "", action: #selector(openAnnouncement), keyEquivalent: "")
    private let announcementSeparator = NSMenuItem.separator()
    private var announcementObserver: NSObjectProtocol?
    private let playerStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lyricsStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var latestPlayerFeedback: PlayerFeedback = .checking
    private var latestLyricsFeedback: LyricsFeedback = .waiting
    private var lyricTimingOffset: TimeInterval = 0
    private let songItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let artistItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var isLyricsHidden = false
    private var freeEditObserver: NSObjectProtocol?
    private var freeResetObserver: NSObjectProtocol?
    private var isPlayerStopped = false
    private var isPlaybackPaused = false
    private var displaySource = ""
    private var displayTranslation: String?
    private var currentTrack: SpotifyTrack?
    private var currentTrackIdentity: String?
    private var currentPlayerTrack: NowPlayingTrack?
    private var currentLines: [LyricLine] = []
    private var latestPlayerPosition: TimeInterval?
    private var latestPlayerUptime: TimeInterval?
    private var displayHighlight: LyricHighlight?
    private var displayProgress: CGFloat = 0
    private var displayStaticText = false
    private var displayIdentity: Int?
    private var scroll = ScrollState()
    private var pollTimer: Timer?
    private var scrollTimer: Timer?
    private var progressTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var pollGeneration = 0
#if DEBUG
    private var lyricsRequestCount = 0
#endif

    func start() {
        player = Self.adapter(for: AppPreferences.playerSource)
        setPlayerFeedback(.checking)
        setLyricsFeedback(.waiting)
        displaySource = L10n.format("Checking %@...", player.source.displayName())
        setupButton()
        setupMenu()
        overlay.freeInteraction.onOpenMainWindow = { [weak self] in self?.openSettingsWindow(page: .lyrics) }
        overlay.freeInteraction.onSettings = { [weak self] in self?.openSettingsWindow(page: .display) }
        overlay.freeInteraction.onClose = { [weak self] in
            self?.isLyricsHidden = true
            self?.updateDisplay()
        }
        overlay.freeInteraction.onColor = { [weak self] in self?.reloadSettings() }
        overlay.freeInteraction.onInteractionChanged = { [weak self] in
            self?.settingsWindowController?.refresh()
            self?.updateDisplay()
        }
        freeEditObserver = NotificationCenter.default.addObserver(forName: FreeLyricsPreferences.editNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.editFreeLyrics() }
        }
        freeResetObserver = NotificationCenter.default.addObserver(forName: FreeLyricsPreferences.resetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resetFreeLyrics() }
        }
        reloadSettings()

        pollTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(pollTimerFired),
            userInfo: nil,
            repeats: true
        )

        startPoll(forceLyricsRefresh: true)
    }

    func stop() {
        lyricsTask?.cancel()
        lyricsTask = nil
        if let freeEditObserver { NotificationCenter.default.removeObserver(freeEditObserver) }
        if let freeResetObserver { NotificationCenter.default.removeObserver(freeResetObserver) }
        lyricsClient.clearDiagnostics()
        pollTimer?.invalidate()
        pollTimer = nil
        scrollTimer?.invalidate()
        scrollTimer = nil
        stopProgressTimer()
        pollTask?.cancel()
        pollTask = nil
        player.shutdown()
        overlay.hide()
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func setupButton() {
        statusItem.button?.toolTip = "NotchMuse"
        statusItem.button?.image = BrandStyle.noteImage()
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        statusItem.button?.title = isPreview ? "P" : ""
        statusItem.button?.imagePosition = isPreview ? .imageLeading : .imageOnly
        if isPreview {
            statusItem.button?.toolTip = "NotchMuse Preview · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development")"
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(playerStatusItem)
        menu.addItem(lyricsStatusItem)
        songItem.isHidden = true
        artistItem.isHidden = true
        menu.addItem(songItem)
        menu.addItem(artistItem)
        menu.addItem(NSMenuItem.separator())
        let visibility = NSMenuItem(title: L10n.text(isLyricsHidden ? "Show Lyrics" : "Hide Lyrics"), action: #selector(toggleLyricsVisibility(_:)), keyEquivalent: "")
        menu.addItem(visibility)
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: L10n.text(mode.rawValue), action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.state = mode == displayMode ? .on : .off
            item.target = self
            displayModeMenu.addItem(item)
        }
        displayModeMenuItem.submenu = displayModeMenu
        menu.addItem(displayModeMenuItem)

        moveLyricsMenuItem.action = #selector(editFreeLyrics)
        resetPositionMenuItem.action = #selector(resetFreeLyrics)
        menu.addItem(moveLyricsMenuItem)
        menu.addItem(resetPositionMenuItem)
        menu.addItem(NSMenuItem.separator())

        for itemPosition in LyricsPosition.allCases {
            let item = NSMenuItem(title: L10n.text(itemPosition.rawValue), action: #selector(setPosition(_:)), keyEquivalent: "")
            item.representedObject = itemPosition.rawValue
            item.state = itemPosition == position ? .on : .off
            item.target = self
            positionMenu.addItem(item)
        }
        positionMenuItem.submenu = positionMenu
        menu.addItem(positionMenuItem)

        let earlierItem = NSMenuItem(title: L10n.text("Earlier (-0.5s)"), action: #selector(nudgeTimingOffset(_:)), keyEquivalent: "")
        earlierItem.representedObject = -0.5
        earlierItem.target = self
        let resetOffsetItem = NSMenuItem(title: L10n.text("Reset (0.0s)"), action: #selector(resetTimingOffset), keyEquivalent: "")
        resetOffsetItem.target = self
        let laterItem = NSMenuItem(title: L10n.text("Later (+0.5s)"), action: #selector(nudgeTimingOffset(_:)), keyEquivalent: "")
        laterItem.representedObject = 0.5
        laterItem.target = self
        timingOffsetMenu.addItem(earlierItem)
        timingOffsetMenu.addItem(resetOffsetItem)
        timingOffsetMenu.addItem(laterItem)
        timingOffsetMenuItem.submenu = timingOffsetMenu
        menu.addItem(timingOffsetMenuItem)
        updateTimingOffsetMenuTitle()

        menu.addItem(NSMenuItem(title: L10n.text("Refresh Lyrics"), action: #selector(refreshLyrics), keyEquivalent: "r"))
        if UpdateController.shared.isAvailable {
            menu.addItem(NSMenuItem(title: L10n.text("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: ""))
        }
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            menu.addItem(NSMenuItem(title: AppPreferences.language == .simplifiedChinese ? "复制歌词诊断" : "Copy Lyrics Diagnostics", action: #selector(copyLyricsDiagnostics), keyEquivalent: ""))
        }
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            menu.addItem(NSMenuItem(title: AppPreferences.language == .simplifiedChinese ? "歌词匹配详情…" : "Lyrics Selection Details…", action: #selector(showLyricsSelection), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: L10n.text("Report Lyrics Issue…"), action: #selector(reportLyricsIssue), keyEquivalent: ""))
        menu.insertItem(NSMenuItem(title: L10n.text("Open NotchMuse"), action: #selector(showSettings), keyEquivalent: ","), at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)
        menu.insertItem(announcementMenuItem, at: 0)
        menu.insertItem(announcementSeparator, at: 1)
        menu.addItem(NSMenuItem.separator())
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let appLabel = (Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true) ? "NotchMuse Preview" : "NotchMuse"
        let versionTitle = buildNumber.isEmpty ? "\(appLabel) v\(shortVersion)" : "\(appLabel) v\(shortVersion) (Build \(buildNumber))"
        let versionItem = NSMenuItem(title: versionTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem(title: L10n.text("Quit"), action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        updateAnnouncementMenuItem()
        announcementObserver = NotificationCenter.default.addObserver(forName: AnnouncementManager.notification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAnnouncementMenuItem() }
        }
        AnnouncementManager.shared.refreshIfNeeded()
        if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true {
            let label = NSMenuItem(title: "NotchMuse Preview · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development")", action: nil, keyEquivalent: "")
            label.isEnabled = false
            menu.insertItem(label, at: 0)
        }
        statusItem.menu = menu
    }

    private func startPoll(forceLyricsRefresh: Bool = false) {
        guard pollTask == nil else { return }
        pollGeneration += 1
        let generation = pollGeneration
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await pollPlayer(forceLyricsRefresh: forceLyricsRefresh)
            if pollGeneration == generation {
                pollTask = nil
            }
        }
    }

    @objc private func pollTimerFired() {
        startPoll()
    }

    private func pollPlayer(forceLyricsRefresh: Bool = false) async {
        guard !Task.isCancelled else { return }
        let source = player.source
        let snapshot = await player.snapshot()
        guard !Task.isCancelled, source == player.source else { return }

        switch snapshot {
        case .closed:
            setPlayerFeedback(.notRunning)
            setLyricsFeedback(.waiting)
            setTrackInfo(nil)
            handlePlayerStopped(display: L10n.format("%@ is not running", player.source.displayName()))
        case .stopped:
            setPlayerFeedback(.connected)
            setLyricsFeedback(.waiting)
            setTrackInfo(nil)
            handlePlayerStopped(display: L10n.format("Waiting for %@", player.source.displayName()))
        case .unavailable:
            setPlayerFeedback(.unavailable)
            setLyricsFeedback(.waiting)
            setTrackInfo(nil)
            let display = player.source == .netEaseMusic
                ? L10n.text("NetEase bridge unavailable. Restart NotchMuse or choose another player.")
                : L10n.format("Cannot connect to %@. Check Automation permission in System Settings.", player.source.displayName())
            handlePlayerStopped(display: display)
        case let .paused(nowPlaying):
            isPlayerStopped = false
            isPlaybackPaused = true
            let track = nowPlaying.spotifyTrack
            let position = nowPlaying.playbackPosition
            currentPlayerTrack = nowPlaying
            setPlayerFeedback(.connected)
            setTrackInfo(nil)
            await updateTrackIfNeeded(track, identity: nowPlaying.observationIdentity, force: forceLyricsRefresh)
            latestPlayerPosition = position
            latestPlayerUptime = nil
            stopProgressTimer()
            let text = LyricClock.moment(at: position, in: currentLines)?.text ?? unpausedFallbackText()
            setDisplay(L10n.format("Paused: %@", text))
        case let .playing(nowPlaying):
            let resumed = isPlaybackPaused
            isPlayerStopped = false
            isPlaybackPaused = false
            let track = nowPlaying.spotifyTrack
            let position = nowPlaying.playbackPosition
            currentPlayerTrack = nowPlaying
            latestPlayerPosition = position
            latestPlayerUptime = ProcessInfo.processInfo.systemUptime
            setPlayerFeedback(.connected)
            setTrackInfo(track)
            await updateTrackIfNeeded(track, identity: nowPlaying.observationIdentity, force: forceLyricsRefresh, resumed: resumed)
            updatePlayingDisplay()
        }
    }

    private func handlePlayerStopped(display: String) {
        lyricsTask?.cancel()
        lyricsTask = nil
        lyricsClient.clearDiagnostics("Player: \(player.source.rawValue)\nTrack title: unavailable\nResolution Status: no current playback selection")
        stopProgressTimer()
        latestPlayerUptime = nil
        isPlayerStopped = true
        isPlaybackPaused = true
        guard AppPreferences.playerStopBehavior == .keep, currentTrack != nil else {
            currentTrack = nil
            currentTrackIdentity = nil
            currentPlayerTrack = nil
            currentLines = []
            setDisplay(display)
            return
        }
        let position = latestPlayerPosition ?? 0
        let text = LyricClock.moment(at: position, in: currentLines)?.text ?? unpausedFallbackText()
        setDisplay(L10n.format("Paused: %@", text))
    }

    private func updateTrackIfNeeded(_ track: SpotifyTrack, identity: String, force: Bool, resumed: Bool = false) async {
        guard Self.shouldUpdateTrack(current: currentTrack, currentIdentity: currentTrackIdentity, next: track, nextIdentity: identity, force: force,
                                    resumed: resumed, playerSource: currentPlayerTrack?.playerSource,
                                    identityRecoveryEnabled: LyricsRuntimeCapabilities.current) else { return }
#if DEBUG
        lyricsRequestCount += 1
        print("[Lyrics] request=\(lyricsRequestCount) source=\(player.source.rawValue) track=\(currentPlayerTrack?.nativeTrackID ?? "-") title=\(track.name) artist=\(track.artist)")
#endif
        currentTrack = track
        currentTrackIdentity = identity
        currentLines = []
        lyricTimingOffset = 0
        updateTimingOffsetMenuTitle()
        setLyricsFeedback(.searching)
        setDisplay(LyricsFeedback.searching.displayText)

        lyricsTask?.cancel()
        let requestingSource = player.source
        let expectedIdentifier = currentPlayerTrack?.nativeTrackID
        let isrc = currentPlayerTrack?.isrc
        let sourceName = currentPlayerTrack?.playerSource.rawValue
        let isNetEase = currentPlayerTrack?.playerSource == .netEaseMusic
        lyricsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let exactSource: LyricsClient.CandidateSource?
                if isNetEase {
                    exactSource = { @Sendable requestedTrack in
                        try await NetEaseExactIDFallback().candidate(for: requestedTrack, expectedIdentifier: expectedIdentifier)
                    }
                } else {
                    exactSource = nil
                }
                let lines = try await lyricsClient.syncedLyrics(for: track, bypassCache: force, exactSource: exactSource,
                                                                playerSource: sourceName,
                                                                nativeTrackID: expectedIdentifier, isrc: isrc)
                guard !Task.isCancelled, currentTrack == track, currentTrackIdentity == identity else { return }
                // Re-read identity before showing a timeline, including switches between polls.
                let confirmed = await player.snapshot()
                guard !Task.isCancelled, currentTrack == track, currentTrackIdentity == identity else { return }
                guard requestingSource == player.source,
                      confirmed.currentTrack?.observationIdentity == identity else {
                    currentTrack = nil
                    currentTrackIdentity = nil
                    lyricsClient.clearDiagnostics("Track title: unavailable\nResolution Status: playback changed during collection; previous report cleared")
                    DebugLog.lyricsDiagnostic("selection.apply rejected=playback_changed_during_collection")
                    return
                }
                currentLines = lines
                if Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true,
                   lyricsClient.selectedProvider == "NetEaseExactID (Preview)", !lines.isEmpty {
                    Logger(subsystem: "app.notchmuse.mac.preview", category: "ExactID").notice("fallback_applied provider=NetEaseExactID line_count=\(lines.count) feedback=available")
                }
                let feedback: LyricsFeedback = lines.isEmpty ? .notFound : .available
                setLyricsFeedback(feedback)
                setDisplay(lines.isEmpty ? feedback.displayText : track.name)
                updatePlayingDisplay()
            } catch let error as LyricsClientError where error == .timeout {
                guard !Task.isCancelled, currentTrack == track, currentTrackIdentity == identity else { return }
                setLyricsFeedback(.timeout)
                setDisplay(LyricsFeedback.timeout.displayText)
            } catch {
                guard !Task.isCancelled, currentTrack == track, currentTrackIdentity == identity else { return }
                setLyricsFeedback(.networkFailure)
                setDisplay(LyricsFeedback.networkFailure.displayText)
            }
        }
    }

    static func shouldUpdateTrack(
        current: SpotifyTrack?,
        currentIdentity: String?,
        next: SpotifyTrack,
        nextIdentity: String,
        force: Bool,
        resumed: Bool = false,
        playerSource: PlayerSource? = nil,
        identityRecoveryEnabled: Bool = false
    ) -> Bool {
        force || current != next || currentIdentity != nextIdentity
            || (resumed && identityRecoveryEnabled && playerSource == .netEaseMusic)
    }

    static func shouldHideLyrics(
        isUserHidden: Bool,
        isPlaying: Bool,
        stopBehavior: PlayerStopBehavior
    ) -> Bool {
        isUserHidden || (!isPlaying && stopBehavior == .hide)
    }

    private func fallbackText() -> String {
        displaySource.isEmpty ? LyricsFeedback.notFound.displayText : displaySource
    }

    private func unpausedFallbackText() -> String {
        let pausedPrefix = L10n.text("Paused: %@").replacingOccurrences(of: "%@", with: "")
        if displaySource.hasPrefix(pausedPrefix) {
            return String(displaySource.dropFirst(pausedPrefix.count))
        }
        return fallbackText()
    }

    private func setDisplay(_ text: String, progress: CGFloat = 0, identity: Int? = nil, highlight: LyricHighlight? = nil, staticText: Bool = false) {
        if text != displaySource || identity != displayIdentity {
            scroll.reset()
        }
        displaySource = text
        displayProgress = progress
        displayStaticText = staticText
        displayHighlight = highlight
        displayIdentity = identity
        updateDisplay()
    }

    private func updateDisplay() {
        if let item = statusItem.menu?.items.first(where: { $0.action == #selector(toggleLyricsVisibility(_:)) }) {
            item.title = L10n.text(isLyricsHidden ? "Show Lyrics" : "Hide Lyrics")
        }
        guard !Self.shouldHideLyrics(
            isUserHidden: isLyricsHidden,
            isPlaying: !isPlayerStopped && !isPlaybackPaused,
            stopBehavior: AppPreferences.playerStopBehavior
        ) || overlay.isEditing else {
            overlay.hide()
            updateScrollTimer(overflows: false)
            return
        }
        let nextLyric: String? = displayIdentity.flatMap { idx in
            let nextIdx = idx + 1
            guard currentLines.indices.contains(nextIdx) else { return nil }
            let t = currentLines[nextIdx].text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        let overflows = overlay.show(
            text: displaySource.isEmpty ? " " : displaySource,
            progress: displayProgress,
            translation: displayTranslation,
            nextLyric: nextLyric,
            highlight: displayHighlight,
            staticText: displayStaticText,
            mode: displayMode,
            position: position,
            notchStyle: notchStyle,
            notchPlacement: AppPreferences.notchPlacement,
            song: currentTrack?.name ?? "",
            artist: currentTrack?.artist ?? "",
            statusItem: statusItem,
            scroll: scroll,
            fontSize: AppPreferences.fontSize,
            animationSpeed: AppPreferences.animationSpeed,
            colorPreset: AppPreferences.colorPreset,
            customLyricsColor: AppPreferences.customLyricsColor,
            customLyricsEndColor: AppPreferences.customLyricsEndColor,
            opacity: AppPreferences.opacity,
            notchBackgroundEnabled: AppPreferences.notchBackgroundEnabled,
            notchBackgroundColor: AppPreferences.notchBackgroundColor,
            notchBackgroundOpacity: AppPreferences.notchBackgroundOpacity,
            notchBackgroundPadding: AppPreferences.notchBackgroundPadding,
            notchHideOnHover: AppPreferences.notchHideOnHover,
            displayTarget: AppPreferences.displayTarget,
            displayWidth: AppPreferences.displayWidth,
            customWidth: AppPreferences.customWidth,
            statusBarOffset: AppPreferences.statusBarOffset
        )
        updateScrollTimer(overflows: overflows)
    }

    private func setPlayerFeedback(_ feedback: PlayerFeedback) {
        latestPlayerFeedback = feedback
        playerStatusItem.title = feedback.menuTitle(for: player.source)
        pushLiveStatusToSettings()
    }

    private func setLyricsFeedback(_ feedback: LyricsFeedback) {
        latestLyricsFeedback = feedback
        lyricsStatusItem.title = feedback.menuTitle(for: player.source)
        pushLiveStatusToSettings()
    }

    private func setTrackInfo(_ track: SpotifyTrack?) {
        songItem.isHidden = track == nil
        artistItem.isHidden = track == nil
        songItem.title = track.map { L10n.format("Song: %@", $0.name) } ?? ""
        artistItem.title = track.map { L10n.format("Artist: %@", $0.artist) } ?? ""
        pushLiveStatusToSettings()
    }

    private func pushLiveStatusToSettings() {
        let needsPermission: PermissionFixKind?
        if AccessibilityManager.requiresAccess(mode: displayMode, position: position) && !AccessibilityManager.isTrusted {
            needsPermission = .accessibility
        } else if latestPlayerFeedback == .unavailable && player.source != .netEaseMusic {
            needsPermission = .automation
        } else {
            needsPermission = nil
        }
        let activeSource = currentPlayerTrack?.playerSource ?? player.source
        let trackText = currentTrack.map { $0.artist.isEmpty ? $0.name : "\($0.name) — \($0.artist)" }
        let liveLyric: String? = (!isPlayerStopped && !isPlaybackPaused && latestLyricsFeedback == .available && !displaySource.isEmpty) ? displaySource : nil
        settingsWindowController?.updateLiveStatus(
            playerName: activeSource.displayName(),
            playerConnected: latestPlayerFeedback == .connected,
            isPlaying: !isPlayerStopped && !isPlaybackPaused && currentTrack != nil,
            isPaused: !isPlayerStopped && isPlaybackPaused && currentTrack != nil,
            trackTitle: currentTrack?.name,
            artistName: currentTrack?.artist,
            trackText: trackText,
            lyricsFeedback: latestLyricsFeedback,
            needsPermission: needsPermission,
            liveLyricLine: liveLyric
        )
        let currentPos = currentPlaybackPosition() ?? latestPlayerPosition ?? 0
        let activeIdx = currentLines.lastIndex { $0.time <= currentPos } ?? -1
        let lineProg = computeImmersiveLineProgress(position: currentPos, activeIndex: activeIdx)
        settingsWindowController?.updateImmersiveLyrics(
            lines: currentLines,
            activeIndex: activeIdx,
            lineProgress: lineProg,
            trackTitle: currentTrack?.name,
            artistName: currentTrack?.artist,
            isPlaying: !isPlayerStopped && !isPlaybackPaused && currentTrack != nil,
            isPaused: !isPlayerStopped && isPlaybackPaused && currentTrack != nil,
            position: currentPos,
            duration: currentTrack?.duration ?? 0,
            lyricsFeedback: latestLyricsFeedback
        )
    }

    private func updateScrollTimer(overflows: Bool) {
        if Self.shouldAnimateScroll(overflows: overflows, isPaused: isPlaybackPaused) {
            guard scrollTimer == nil else { return }
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateDisplay()
                }
            }
        } else {
            stopScrollTimer()
        }
    }

    static func shouldAnimateScroll(overflows: Bool, isPaused: Bool) -> Bool {
        overflows && !isPaused
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func updatePlayingDisplay() {
        guard let position = currentPlaybackPosition() else {
            stopProgressTimer()
            return
        }
        if let moment = LyricClock.moment(at: position, in: currentLines) {
            displayTranslation = AppPreferences.bilingualLyricsEnabled ? moment.translation : nil
            setDisplay(moment.text, progress: moment.progress, identity: moment.identity, highlight: moment.highlight,
                       staticText: moment.timingFidelity == .lineStartOnly || moment.timingFidelity == .estimated)
            settingsWindowController?.updateLiveLyricLine(moment.text)
            let activeIdx = currentLines.lastIndex { $0.time <= position } ?? -1
            let lineProg = computeImmersiveLineProgress(position: position, activeIndex: activeIdx)
            settingsWindowController?.updateImmersiveLyrics(
                lines: currentLines,
                activeIndex: activeIdx,
                lineProgress: lineProg,
                trackTitle: currentTrack?.name,
                artistName: currentTrack?.artist,
                isPlaying: !isPlayerStopped && !isPlaybackPaused && currentTrack != nil,
                isPaused: !isPlayerStopped && isPlaybackPaused && currentTrack != nil,
                position: position,
                duration: currentTrack?.duration ?? 0,
                lyricsFeedback: latestLyricsFeedback
            )
        } else {
            displayTranslation = nil
            setDisplay(fallbackText())
            settingsWindowController?.updateLiveLyricLine(nil)
            settingsWindowController?.updateImmersiveLyrics(
                lines: currentLines,
                activeIndex: -1,
                lineProgress: 0,
                trackTitle: currentTrack?.name,
                artistName: currentTrack?.artist,
                isPlaying: !isPlayerStopped && !isPlaybackPaused && currentTrack != nil,
                isPaused: !isPlayerStopped && isPlaybackPaused && currentTrack != nil,
                position: position,
                duration: currentTrack?.duration ?? 0,
                lyricsFeedback: latestLyricsFeedback
            )
        }
        updateProgressTimer()
    }

    private func computeImmersiveLineProgress(position: TimeInterval, activeIndex: Int) -> CGFloat {
        guard currentLines.indices.contains(activeIndex) else { return 0 }
        let line = currentLines[activeIndex]
        let nextTime: TimeInterval
        if let end = line.endTime, end > line.time + 0.2 {
            nextTime = end
        } else if currentLines.indices.contains(activeIndex + 1) {
            nextTime = currentLines[activeIndex + 1].time
        } else {
            nextTime = max(line.time + 3.0, currentTrack?.duration ?? (line.time + 4.0))
        }
        let span = max(0.35, nextTime - line.time)
        return CGFloat(min(1, max(0, (position - line.time) / span)))
    }

    private func currentPlaybackPosition() -> TimeInterval? {
        guard let latestPlayerPosition else { return nil }
        let base: TimeInterval
        if let latestPlayerUptime {
            base = latestPlayerPosition + ProcessInfo.processInfo.systemUptime - latestPlayerUptime
        } else {
            base = latestPlayerPosition
        }
        return max(0, base + lyricTimingOffset)
    }

    private func updateProgressTimer() {
        guard !isLyricsHidden, latestPlayerUptime != nil, !currentLines.isEmpty else {
            stopProgressTimer()
            return
        }
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayingDisplay()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    @objc private func editFreeLyrics() {
        UserDefaults.standard.set(DisplayMode.free.rawValue, forKey: AppPreferences.displayModeKey)
        isLyricsHidden = false
        overlay.freeInteraction.beginEditing()
        reloadSettings()
        settingsWindowController?.refresh()
    }

    @objc private func resetFreeLyrics() {
        UserDefaults.standard.removeObject(forKey: FreeLyricsPreferences.horizontalAnchorKey)
        UserDefaults.standard.removeObject(forKey: FreeLyricsPreferences.verticalAnchorKey)
        editFreeLyrics()
    }

    @objc private func toggleLyricsVisibility(_ sender: NSMenuItem) {
        isLyricsHidden.toggle()
        sender.title = isLyricsHidden ? L10n.text("Show Lyrics") : L10n.text("Hide Lyrics")
        if isLyricsHidden {
            stopProgressTimer()
            stopScrollTimer()
            overlay.hide()
        } else {
            scroll.reset()
            displayIdentity = nil
            updatePlayingDisplay()
            startPoll()
        }
    }

    @objc private func setPosition(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let newPosition = LyricsPosition(rawValue: rawValue) else {
            return
        }
        applyPosition(newPosition)
    }

    private func applyPosition(_ newPosition: LyricsPosition) {
        UserDefaults.standard.set(newPosition.rawValue, forKey: AppPreferences.positionKey)
        reloadSettings()
        AccessibilityManager.requestIfNeeded(mode: displayMode, position: newPosition)
    }

    private func reloadSettings() {
        NSApp.setActivationPolicy(AppPreferences.showInDock ? .regular : .accessory)
        statusItem.isVisible = AppPreferences.showMenuBarIcon
        let selectedSource = AppPreferences.playerSource
        if selectedSource != player.source {
            pollTask?.cancel()
            pollTask = nil
            pollGeneration += 1
            lyricsTask?.cancel()
            lyricsTask = nil
            player.shutdown()
            lyricsClient.clearDiagnostics()
            player = Self.adapter(for: selectedSource)
            latestPlayerUptime = nil
            setPlayerFeedback(.checking)
            setLyricsFeedback(.waiting)
            handlePlayerStopped(display: L10n.format("Checking %@...", selectedSource.displayName()))
            startPoll(forceLyricsRefresh: true)
        }
        displayMode = AppPreferences.displayMode
        position = AppPreferences.position
        notchStyle = AppPreferences.notchStyle
        for item in displayModeMenu.items {
            item.state = item.representedObject as? String == displayMode.rawValue ? .on : .off
        }
        moveLyricsMenuItem.title = L10n.text(displayMode == .free ? "Move Lyrics" : "Enter Free Position & Move")
        resetPositionMenuItem.isHidden = displayMode != .free
        positionMenuItem.isEnabled = displayMode == .statusBar
        for item in positionMenu.items {
            item.state = item.representedObject as? String == position.rawValue ? .on : .off
        }
        scroll.reset()
        updateDisplay()
        pushLiveStatusToSettings()
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: rawValue) else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: AppPreferences.displayModeKey)
        isLyricsHidden = false
        reloadSettings()
        settingsWindowController?.refresh()
        AccessibilityManager.requestIfNeeded(mode: mode, position: position)
    }

    @objc private func nudgeTimingOffset(_ sender: NSMenuItem) {
        guard let delta = sender.representedObject as? Double else { return }
        lyricTimingOffset = ((lyricTimingOffset + delta) * 10).rounded() / 10
        updateTimingOffsetMenuTitle()
        updatePlayingDisplay()
    }

    @objc private func resetTimingOffset() {
        lyricTimingOffset = 0
        updateTimingOffsetMenuTitle()
        updatePlayingDisplay()
    }

    private func updateTimingOffsetMenuTitle() {
        if abs(lyricTimingOffset) < 0.05 {
            timingOffsetMenuItem.title = L10n.text("Lyric Timing Offset")
        } else {
            let formatted = String(format: "%+.1fs", lyricTimingOffset)
            timingOffsetMenuItem.title = L10n.format("Lyric Timing Offset (%@)", formatted)
        }
    }

    static func adapter(for source: PlayerSource) -> any MusicPlayerAdapter {
        switch source {
        case .auto: AutoDetectAdapter()
        case .spotify: SpotifyAdapter()
        case .appleMusic: AppleMusicAdapter()
        case .netEaseMusic: NetEaseMusicAdapter()
        default: MediaRemotePlayerAdapter(source: source)
        }
    }

    @objc private func refreshLyrics() {
        startPoll(forceLyricsRefresh: true)
    }

    @objc func showLyricsSelection() {
        guard Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true else { return }
        let alert = NSAlert()
        alert.messageText = AppPreferences.language == .simplifiedChinese ? "歌词匹配详情" : "Lyrics Selection Details"
        let previewStatus = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
            ? "NotchMuse Preview · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development")\nMenu Bar Icon: \(statusItem.isVisible ? "visible" : "hidden") / \(statusItem.button?.title ?? "")\n\n"
            : ""
        let isPreview = Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true
        alert.informativeText = previewStatus
        if isPreview {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 340))
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .bezelBorder
            let textView = NSTextView(frame: scrollView.bounds)
            textView.isEditable = false
            textView.isSelectable = true
            textView.isVerticallyResizable = true
            textView.maxSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            textView.string = lyricsClient.diagnosticsText
            scrollView.documentView = textView
            alert.accessoryView = scrollView
            alert.addButton(withTitle: AppPreferences.language == .simplifiedChinese ? "关闭" : "Close")
            alert.addButton(withTitle: AppPreferences.language == .simplifiedChinese ? "复制歌词诊断" : "Copy Lyrics Diagnostics")
        }
        if alert.runModal() == .alertSecondButtonReturn, isPreview { copyLyricsDiagnostics() }
    }

    @objc func copyLyricsDiagnostics() {
        guard Bundle.main.object(forInfoDictionaryKey: "NotchMusePreview") as? Bool == true else { return }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Development"
        let report = "NotchMuse Preview · Build \(build)\n\n" + lyricsClient.diagnosticsText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    @objc private func reportLyricsIssue() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        guard let url = LyricsIssueReporter.mailtoURL(
            track: currentPlayerTrack,
            provider: lyricsClient.selectedProvider,
            timing: lyricsClient.selectedDocument,
            selection: lyricsClient.selectionDiagnostics,
            appVersion: version
        ) else {
            let alert = NSAlert()
            alert.messageText = L10n.text("Feedback email is not configured")
            alert.informativeText = L10n.text("Set FEEDBACK_EMAIL before distributing this feature.")
            alert.runModal()
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func showSettings() {
        openSettingsWindow(page: nil)
    }

    func openSettingsWindow(page: SettingsPage?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController { [weak self] in
                self?.reloadSettings()
            }
            settingsWindowController?.onFreeLockChanged = { [weak self] in
                self?.overlay.freeInteraction.endEditing()
            }
            settingsWindowController?.onDisplayModeSelected = { [weak self] in
                guard let self else { return }
                self.isLyricsHidden = false
                self.updateDisplay()
            }
            settingsWindowController?.onRetryLyricsMatch = { [weak self] in
                self?.startPoll(forceLyricsRefresh: true)
            }
            settingsWindowController?.onMediaCommand = { [weak self] command in
                guard let self else { return }
                if command == .playPause, self.currentPlayerTrack == nil {
                    let preferred = AppPreferences.preferredLaunchPlayer
                    if preferred == .none {
                        return
                    }
                    if let target = preferred.resolveApplicationURL() {
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = false
                        NSWorkspace.shared.openApplication(at: target.url, configuration: config) { _, _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                                SystemMediaTransport.send(.playPause, activeSource: target.source)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    self?.startPoll()
                                }
                            }
                        }
                        return
                    }
                }
                let activeSource = self.currentPlayerTrack?.playerSource ?? self.player.source
                SystemMediaTransport.send(command, activeSource: activeSource)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.startPoll()
                }
            }
            settingsWindowController?.onMediaSeek = { [weak self] seconds in
                guard let self else { return }
                let activeSource = self.currentPlayerTrack?.playerSource ?? self.player.source
                SystemMediaTransport.seek(to: seconds, activeSource: activeSource)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.startPoll()
                }
            }
        }
        settingsWindowController?.show(page: page)
        pushLiveStatusToSettings()
    }

    #if DEBUG
    static func testVocalGapPresentation() {
        let controller = MenuBarController()
        controller.isLyricsHidden = true // Exercise real display state without showing a fixture over user lyrics.
        defer { controller.overlay.hide(); NSStatusBar.system.removeStatusItem(controller.statusItem) }
        let next = LyricLine(time: 20, text: "Next", endTime: 23)
        let estimatedText = "One two three four five six seven eight"
        for line in [LyricLine(time: 10, text: estimatedText), LyricLine(time: 10, text: estimatedText, endTime: 20, endTimeIsEstimated: true)] {
            controller.currentLines = [line, next]
            for position in [10.0, 12.5, 15, 17.5, 19.999] {
                controller.latestPlayerPosition = position
                controller.updatePlayingDisplay()
                precondition(controller.displayProgress == 1, "Start-only and estimated lyrics remain fully lit without a guessed sweep")
                precondition(controller.displayStaticText && controller.displayHighlight == nil && controller.displaySource == estimatedText, "Static display does not fabricate word timestamps or advance the line early")
            }
        }
        for line in [LyricLine(time: 10, text: "Fixture", endTime: 15),
                     LyricLine(time: 10, text: "Fixture", endTime: 15, segments: [LyricSegment(time: 10, endTime: 15, text: "Fixture")])] {
            controller.currentLines = [line, next]
            controller.latestPlayerPosition = 12.5
            controller.updatePlayingDisplay()
            precondition(!controller.displayStaticText && controller.displayProgress == 0.5, "Authentic five-second vocal timing remains proportional")
            for position in [15.0, 17.5, 19.999, 15, 12.5] {
                controller.latestPlayerPosition = position
                controller.updatePlayingDisplay()
                precondition(controller.displayProgress == (position >= 15 ? 1 : 0.5), "Real vocal ends hold through the five-second gap and follow seek backwards")
            }
            controller.latestPlayerPosition = 20
            controller.updatePlayingDisplay()
            precondition(controller.displaySource == "Next" && controller.displayProgress == 0, "Next timed line starts only at source timestamp")
        }
        print("PASS: vocal-gap display checks — authentic timing retained; start-only and estimated timing stays static")
    }

    static func testDisplayModeReopen() {
        let defaults = UserDefaults.standard
        let keys = [AppPreferences.displayModeKey, AppPreferences.playerSourceKey, "NSWindow Frame NotchMuseSettings"] + FreeLyricsPreferences.keys
        let saved = keys.map { defaults.object(forKey: $0) }
        defaults.set(PlayerSource.spotify.rawValue, forKey: AppPreferences.playerSourceKey)
        let controller = MenuBarController()
        defer {
            controller.settingsWindowController?.close()
            controller.overlay.hide()
            controller.scrollTimer?.invalidate()
            NSStatusBar.system.removeStatusItem(controller.statusItem)
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        controller.showSettings()
        func findModeControl(_ view: NSView) -> NSSegmentedControl? {
            if let control = view as? NSSegmentedControl,
               control.action == NSSelectorFromString("displayModeChanged") { return control }
            return view.subviews.lazy.compactMap { findModeControl($0) }.first
        }
        let control = findModeControl(controller.settingsWindowController!.window!.contentView!)!
        for mode in [DisplayMode.free, .notch, .free, .free] {
            controller.isLyricsHidden = true // State left by the overlay's close action.
            controller.overlay.hide()
            controller.showSettings()
            precondition(controller.isLyricsHidden, "Opening settings alone must not reopen closed lyrics")
            control.selectedSegment = DisplayMode.allCases.firstIndex(of: mode)!
            _ = NSApp.sendAction(control.action!, to: control.target, from: control)
            precondition(!controller.isLyricsHidden, "Selecting a display mode must reopen closed lyrics, including reselecting the same mode")
            if mode == .free {
                precondition(controller.overlay.freeInteraction.window.isVisible, "Free lyrics must actually reopen")
            }
        }
        func findLockControl(_ view: NSView) -> NSSwitch? {
            if let control = view as? NSSwitch,
               control.action == NSSelectorFromString("freeLockChanged") { return control }
            return view.subviews.lazy.compactMap { findLockControl($0) }.first
        }
        let lockControl = findLockControl(controller.settingsWindowController!.window!.contentView!)!
        controller.overlay.freeInteraction.beginEditing()
        lockControl.state = .on
        _ = NSApp.sendAction(lockControl.action!, to: lockControl.target, from: lockControl)
        precondition(!controller.overlay.isEditing, "Locking from settings must end temporary editing")
        precondition(defaults.bool(forKey: FreeLyricsPreferences.lockedKey), "Settings lock persists")
        precondition(!controller.overlay.freeInteraction.testDragSurface.isDragEnabled, "Settings lock disables direct drag surface")
        print("PASS: display-mode selection reopens closed lyrics, including same-mode reselection; settings locking ends editing")
    }
    #endif

    private func updateAnnouncementMenuItem() {
        if let active = AnnouncementManager.shared.activeAnnouncement {
            announcementMenuItem.title = "● \(active.localizedTitle) ›"
            announcementMenuItem.isHidden = false
            announcementSeparator.isHidden = false
        } else {
            announcementMenuItem.isHidden = true
            announcementSeparator.isHidden = true
        }
    }

    @objc private func openAnnouncement() {
        AnnouncementManager.shared.openActive()
    }

    @objc private func checkForUpdates() {
        UpdateController.shared.checkForUpdates()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
