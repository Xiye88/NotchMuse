import AppKit
import Foundation

enum SpotifyFeedback {
    case checking
    case connected
    case notRunning
    case unavailable

    var menuTitle: String {
        switch self {
        case .checking: return L10n.text("Spotify: Checking...")
        case .connected: return L10n.text("Spotify: Connected")
        case .notRunning: return L10n.text("Spotify: Not Running")
        case .unavailable: return L10n.text("Spotify: Connection Error")
        }
    }
}

enum LyricsFeedback {
    case waiting
    case searching
    case available
    case notFound
    case networkFailure

    var menuTitle: String {
        switch self {
        case .waiting: return L10n.text("Lyrics: Waiting for Spotify")
        case .searching: return L10n.text("Lyrics: Searching...")
        case .available: return L10n.text("Lyrics: Available")
        case .notFound: return L10n.text("Lyrics: Not Found")
        case .networkFailure: return L10n.text("Lyrics: Network Error")
        }
    }

    var displayText: String {
        switch self {
        case .waiting: return L10n.text("Waiting for Spotify")
        case .searching: return L10n.text("Changing song...")
        case .available: return L10n.text("Lyrics available")
        case .notFound: return L10n.text("No lyrics found")
        case .networkFailure: return L10n.text("Lyrics network unavailable")
        }
    }
}

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem = {
        let autosaveName = "NotchMuseStatusItem"
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = autosaveName
        item.isVisible = true
        return item
    }()
    private let overlay = OverlayLyricsWindow()
    private let lyricsClient = LyricsClient()
    private var displayMode = AppPreferences.displayMode
    private var position = AppPreferences.position
    private var notchStyle = AppPreferences.notchStyle
    private var settingsWindowController: SettingsWindowController?
    private let positionMenu = NSMenu()
    private let positionMenuItem = NSMenuItem(title: L10n.text("Status Bar Position"), action: nil, keyEquivalent: "")
    private let spotifyStatusItem = NSMenuItem(title: SpotifyFeedback.checking.menuTitle, action: nil, keyEquivalent: "")
    private let lyricsStatusItem = NSMenuItem(title: LyricsFeedback.waiting.menuTitle, action: nil, keyEquivalent: "")
    private let songItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let artistItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var isLyricsHidden = false
    private var displaySource = L10n.text("Checking Spotify...")
    private var currentTrack: SpotifyTrack?
    private var currentLines: [LyricLine] = []
    private var latestSpotifyPosition: TimeInterval?
    private var latestSpotifyUptime: TimeInterval?
    private var displayProgress: CGFloat = 0
    private var displayIdentity: Int?
    private var scroll = ScrollState()
    private var pollTimer: Timer?
    private var scrollTimer: Timer?
    private var progressTimer: Timer?
    private var pollTask: Task<Void, Never>?

    func start() {
        setupButton()
        setupMenu()
        reloadSettings()
        Task { @MainActor [weak self] in
            self?.showFirstLaunchGuideIfNeeded()
        }

        pollTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(pollTimerFired),
            userInfo: nil,
            repeats: true
        )

        startPoll(forceLyricsRefresh: true)
    }

    func reveal() {
        showMenu()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        scrollTimer?.invalidate()
        scrollTimer = nil
        stopProgressTimer()
        pollTask?.cancel()
        pollTask = nil
        overlay.hide()
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func setupButton() {
        statusItem.button?.toolTip = "NotchMuse"
        statusItem.button?.image = BrandStyle.noteImage()
        statusItem.button?.imagePosition = .imageOnly
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(spotifyStatusItem)
        menu.addItem(lyricsStatusItem)
        songItem.isHidden = true
        artistItem.isHidden = true
        menu.addItem(songItem)
        menu.addItem(artistItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.text("Hide Lyrics"), action: #selector(toggleLyricsVisibility(_:)), keyEquivalent: ""))
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

        menu.addItem(NSMenuItem(title: L10n.text("Refresh Lyrics"), action: #selector(refreshLyrics), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: L10n.text("Settings…"), action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.text("Quit"), action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    private func startPoll(forceLyricsRefresh: Bool = false) {
        guard pollTask == nil else { return }
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await pollSpotify(forceLyricsRefresh: forceLyricsRefresh)
            pollTask = nil
        }
    }

    @objc private func pollTimerFired() {
        startPoll()
    }

    private func pollSpotify(forceLyricsRefresh: Bool = false) async {
        guard !Task.isCancelled else { return }

        switch await SpotifyReader.read() {
        case .closed:
            setSpotifyFeedback(.notRunning)
            setLyricsFeedback(.waiting)
            setTrackInfo(nil)
            currentTrack = nil
            currentLines = []
            stopProgressTimer()
            setDisplay(L10n.text("Spotify is not running"))
        case .unavailable:
            setSpotifyFeedback(.unavailable)
            setLyricsFeedback(.waiting)
            setTrackInfo(nil)
            stopProgressTimer()
            setDisplay(L10n.text("Cannot connect to Spotify"))
        case let .paused(track, position):
            setSpotifyFeedback(.connected)
            setTrackInfo(nil)
            await updateTrackIfNeeded(track, force: forceLyricsRefresh)
            latestSpotifyPosition = position
            latestSpotifyUptime = nil
            stopProgressTimer()
            let text = LyricClock.moment(at: position, in: currentLines)?.text ?? unpausedFallbackText()
            setDisplay(L10n.format("Paused: %@", text))
        case let .playing(track, position):
            setSpotifyFeedback(.connected)
            setTrackInfo(track)
            await updateTrackIfNeeded(track, force: forceLyricsRefresh)
            latestSpotifyPosition = position
            latestSpotifyUptime = ProcessInfo.processInfo.systemUptime
            updatePlayingDisplay()
        }
    }

    private func updateTrackIfNeeded(_ track: SpotifyTrack, force: Bool) async {
        guard force || currentTrack != track else { return }
        currentTrack = track
        currentLines = []
        setLyricsFeedback(.searching)
        setDisplay(LyricsFeedback.searching.displayText)

        do {
            let lines = try await lyricsClient.syncedLyrics(for: track, bypassCache: force)
            guard !Task.isCancelled, currentTrack == track else { return }
            currentLines = lines
            let feedback: LyricsFeedback = lines.isEmpty ? .notFound : .available
            setLyricsFeedback(feedback)
            setDisplay(lines.isEmpty ? feedback.displayText : track.name)
        } catch {
            guard !Task.isCancelled, currentTrack == track else { return }
            setLyricsFeedback(.networkFailure)
            setDisplay(LyricsFeedback.networkFailure.displayText)
        }
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

    private func setDisplay(_ text: String, progress: CGFloat = 0, identity: Int? = nil) {
        if text != displaySource || identity != displayIdentity {
            scroll.reset()
        }
        displaySource = text
        displayProgress = progress
        displayIdentity = identity
        updateDisplay()
    }

    private func updateDisplay() {
        guard !isLyricsHidden else {
            overlay.hide()
            updateScrollTimer(overflows: false)
            return
        }
        let overflows = overlay.show(
            text: displaySource.isEmpty ? " " : displaySource,
            progress: displayProgress,
            mode: displayMode,
            position: position,
            notchStyle: notchStyle,
            song: currentTrack?.name ?? "",
            artist: currentTrack?.artist ?? "",
            statusItem: statusItem,
            scroll: scroll,
            fontSize: AppPreferences.fontSize,
            animationSpeed: AppPreferences.animationSpeed,
            colorPreset: AppPreferences.colorPreset,
            opacity: AppPreferences.opacity,
            displayTarget: AppPreferences.displayTarget,
            displayWidth: AppPreferences.displayWidth,
            customWidth: AppPreferences.customWidth
        )
        updateScrollTimer(overflows: overflows)
    }

    private func setSpotifyFeedback(_ feedback: SpotifyFeedback) {
        spotifyStatusItem.title = feedback.menuTitle
    }

    private func setLyricsFeedback(_ feedback: LyricsFeedback) {
        lyricsStatusItem.title = feedback.menuTitle
    }

    private func setTrackInfo(_ track: SpotifyTrack?) {
        songItem.isHidden = track == nil
        artistItem.isHidden = track == nil
        songItem.title = track.map { L10n.format("Song: %@", $0.name) } ?? ""
        artistItem.title = track.map { L10n.format("Artist: %@", $0.artist) } ?? ""
    }

    private func showFirstLaunchGuideIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: AppPreferences.hasShownFirstLaunchGuideKey) else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.text("Welcome to NotchMuse 🎵")
        alert.informativeText = L10n.text("First Launch Guide")
        alert.addButton(withTitle: L10n.text("Continue"))
        alert.window.level = .floating
        alert.window.orderFrontRegardless()
        alert.runModal()
        UserDefaults.standard.set(true, forKey: AppPreferences.hasShownFirstLaunchGuideKey)
    }

    private func showMenu() {
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func updateScrollTimer(overflows: Bool) {
        if overflows {
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
            setDisplay(moment.text, progress: moment.progress, identity: moment.identity)
        } else {
            setDisplay(fallbackText())
        }
        updateProgressTimer()
    }

    private func currentPlaybackPosition() -> TimeInterval? {
        guard let latestSpotifyPosition, let latestSpotifyUptime else { return latestSpotifyPosition }
        return latestSpotifyPosition + ProcessInfo.processInfo.systemUptime - latestSpotifyUptime
    }

    private func updateProgressTimer() {
        guard !isLyricsHidden, latestSpotifyUptime != nil, !currentLines.isEmpty else {
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
        displayMode = AppPreferences.displayMode
        position = AppPreferences.position
        notchStyle = AppPreferences.notchStyle
        positionMenuItem.isEnabled = displayMode == .statusBar
        for item in positionMenu.items {
            item.state = item.representedObject as? String == position.rawValue ? .on : .off
        }
        scroll.reset()
        updateDisplay()
    }

    @objc private func refreshLyrics() {
        startPoll(forceLyricsRefresh: true)
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController { [weak self] in
                self?.reloadSettings()
            }
        }
        settingsWindowController?.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
