import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private let overlay = OverlayLyricsWindow()
    private let lyricsClient = LyricsClient()
    private var position = LyricsPosition(
        rawValue: UserDefaults.standard.string(forKey: "LyricsPosition") ?? ""
    ) ?? .both
    private var isPaused = false
    private var displaySource = "Open Spotify"
    private var currentTrack: SpotifyTrack?
    private var currentLines: [LyricLine] = []
    private var scroll = ScrollState()
    private var pollTimer: Timer?
    private var scrollTimer: Timer?

    func start() {
        setupButton()
        setupMenu()
        requestMenuBarAccessIfNeeded()
        updateDisplay()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollSpotify()
            }
        }

        Task { @MainActor in
            await pollSpotify(forceLyricsRefresh: true)
        }
    }

    func reveal() {
        showMenu()
    }

    private func setupButton() {
        statusItem.length = NSStatusItem.squareLength
        statusItem.button?.toolTip = "Menu Bar Lyrics"
        statusItem.button?.image = BrandStyle.noteImage()
        statusItem.button?.imagePosition = .imageOnly
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pause Lyrics", action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        for itemPosition in LyricsPosition.allCases {
            let item = NSMenuItem(title: itemPosition.menuTitle, action: #selector(setPosition(_:)), keyEquivalent: "")
            item.representedObject = itemPosition.rawValue
            item.state = itemPosition == position ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Lyrics", action: #selector(refreshLyrics), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    private func pollSpotify(forceLyricsRefresh: Bool = false) async {
        guard !isPaused else { return }

        switch await SpotifyReader.read() {
        case .closed:
            currentTrack = nil
            currentLines = []
            setDisplay("Open Spotify")
        case .unavailable:
            setDisplay("Spotify unavailable")
        case let .paused(track, position):
            await updateTrackIfNeeded(track, force: forceLyricsRefresh)
            let text = LyricClock.currentLine(at: position, in: currentLines) ?? unpausedFallbackText()
            setDisplay("Paused: \(text)")
        case let .playing(track, position):
            await updateTrackIfNeeded(track, force: forceLyricsRefresh)
            setDisplay(LyricClock.currentLine(at: position, in: currentLines) ?? fallbackText())
        }
    }

    private func updateTrackIfNeeded(_ track: SpotifyTrack, force: Bool) async {
        guard force || currentTrack != track else { return }
        currentTrack = track
        currentLines = []
        setDisplay("Loading lyrics...")

        do {
            let lines = try await lyricsClient.syncedLyrics(for: track, bypassCache: force)
            currentLines = lines
            setDisplay(lines.isEmpty ? "No synced lyrics" : track.name)
        } catch {
            setDisplay(displaySource.isEmpty ? "No synced lyrics" : displaySource)
        }
    }

    private func fallbackText() -> String {
        currentLines.isEmpty ? "No synced lyrics" : displaySource
    }

    private func unpausedFallbackText() -> String {
        if displaySource.hasPrefix("Paused: ") {
            return String(displaySource.dropFirst("Paused: ".count))
        }
        return fallbackText()
    }

    private func setDisplay(_ text: String) {
        if text != displaySource {
            scroll.reset()
        }
        displaySource = text
        updateDisplay()
    }

    private func updateDisplay() {
        let overflows = overlay.show(
            text: displaySource.isEmpty ? " " : "♪ \(displaySource)",
            position: position,
            statusItem: statusItem,
            scroll: scroll
        )
        updateScrollTimer(overflows: overflows)
    }

    private func requestMenuBarAccessIfNeeded() {
        if position == .left || position == .both {
            MenuBarSafety.requestAccess()
        }
    }

    private func showMenu() {
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func updateScrollTimer(overflows: Bool) {
        if overflows {
            guard scrollTimer == nil else { return }
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateDisplay()
                }
            }
        } else {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        sender.title = isPaused ? "Resume Lyrics" : "Pause Lyrics"
        if isPaused {
            setDisplay("Lyrics paused")
        } else {
            Task { @MainActor in
                await pollSpotify(forceLyricsRefresh: true)
            }
        }
    }

    @objc private func setPosition(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let newPosition = LyricsPosition(rawValue: rawValue) else {
            return
        }
        position = newPosition
        UserDefaults.standard.set(newPosition.rawValue, forKey: "LyricsPosition")
        requestMenuBarAccessIfNeeded()
        for item in statusItem.menu?.items ?? [] where item.action == #selector(setPosition(_:)) {
            item.state = item === sender ? .on : .off
        }
        scroll.reset()
        updateDisplay()
    }

    @objc private func refreshLyrics() {
        Task { @MainActor in
            await pollSpotify(forceLyricsRefresh: true)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
