import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private enum Width: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var pixels: CGFloat {
            switch self {
            case .small: return 420
            case .medium: return 720
            case .large: return 980
            }
        }

        var characters: Int {
            switch self {
            case .small: return 46
            case .medium: return 80
            case .large: return 110
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private let overlay = OverlayLyricsWindow()
    private let lyricsClient = LyricsClient()
    private var width: Width = .small
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
        updateDisplay()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollSpotify()
            }
        }

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scroll.advance()
                self?.updateDisplay()
            }
        }

        Task { @MainActor in
            await pollSpotify(forceLyricsRefresh: true)
        }
    }

    private func setupButton() {
        statusItem.length = 28
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        statusItem.button?.alignment = .center
        statusItem.button?.lineBreakMode = .byClipping
        statusItem.button?.toolTip = "Menu Bar Lyrics"
        statusItem.button?.title = "♪"
        overlay.show(width: width.pixels)
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pause Lyrics", action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        for itemWidth in Width.allCases {
            let item = NSMenuItem(title: "Width: \(itemWidth.rawValue)", action: #selector(setWidth(_:)), keyEquivalent: "")
            item.representedObject = itemWidth.rawValue
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
            let lines = try await lyricsClient.syncedLyrics(for: track)
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
        statusItem.length = 28
        let visible = scroll.visibleText(displaySource, maxCharacters: width.characters)
        statusItem.button?.title = "♪"
        overlay.show(width: width.pixels)
        overlay.setText(visible.isEmpty ? " " : "♪ \(visible)")
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

    @objc private func setWidth(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let newWidth = Width(rawValue: rawValue) else {
            return
        }
        width = newWidth
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
