import AppKit

// Coordinates are fractions of usable travel in points, independent of display scale.
struct FreeLyricsAnchor: Codable, Equatable {
    let screenID: String
    let x: Double
    let y: Double
}

enum FreeLyricsGeometry {
    static func screenIndex(savedID: String?, screenIDs: [String], preferredIndex: Int) -> Int? {
        guard !screenIDs.isEmpty else { return nil }
        if let savedID { return screenIDs.firstIndex(of: savedID) ?? 0 }
        return screenIDs.indices.contains(preferredIndex) ? preferredIndex : 0
    }

    static func frame(anchor: FreeLyricsAnchor?, size: NSSize, visible: NSRect) -> NSRect {
        let size = NSSize(width: min(size.width, visible.width), height: min(size.height, visible.height))
        let x = anchor?.x.isFinite == true ? min(1, max(0, anchor!.x)) : 0.5
        let y = anchor?.y.isFinite == true ? min(1, max(0, anchor!.y)) : 0.18
        return NSRect(x: visible.minX + (visible.width - size.width) * x,
                      y: visible.minY + (visible.height - size.height) * y, width: size.width, height: size.height)
    }

    static func anchor(frame: NSRect, visible: NSRect, screenID: String) -> FreeLyricsAnchor {
        FreeLyricsAnchor(screenID: screenID,
            x: min(1, max(0, (frame.minX - visible.minX) / max(1, visible.width - frame.width))),
            y: min(1, max(0, (frame.minY - visible.minY) / max(1, visible.height - frame.height))))
    }
}

enum FreeLyricsPreferences {
    static let verticalKey = "FreeLyricsVertical"
    static let lockedKey = "FreeLyricsLocked"
    static let passThroughKey = "FreeLyricsPassThrough"
    static let horizontalAnchorKey = "FreeLyricsHorizontalAnchor"
    static let verticalAnchorKey = "FreeLyricsVerticalAnchor"
    static let keys = [verticalKey, lockedKey, passThroughKey, horizontalAnchorKey, verticalAnchorKey]
    static var vertical: Bool { UserDefaults.standard.bool(forKey: verticalKey) }
    static func anchorKey(vertical: Bool) -> String { vertical ? verticalAnchorKey : horizontalAnchorKey }
    static func load(vertical: Bool, defaults: UserDefaults = .standard) -> FreeLyricsAnchor? {
        defaults.data(forKey: anchorKey(vertical: vertical)).flatMap { try? JSONDecoder().decode(FreeLyricsAnchor.self, from: $0) }
    }
    static func save(_ anchor: FreeLyricsAnchor, vertical: Bool, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(anchor) { defaults.set(data, forKey: anchorKey(vertical: vertical)) }
    }
    static let editNotification = Notification.Name("NotchMuseEditFreeLyrics")
    static let resetNotification = Notification.Name("NotchMuseResetFreeLyrics")
}

struct FreeLyricsPolicy {
    var editing = false
    var locked = false
    var passThrough = false
    var hideOnHover = false
    var ignoresMouseEvents: Bool { passThrough && !editing }
    var canMove: Bool { editing || (!locked && !passThrough) }
    func hidesLyrics(hovered: Bool) -> Bool { hideOnHover && hovered && !editing }
}

@MainActor
private final class FreeLyricsHoverView: NSVisualEffectView {
    var onHover: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

@MainActor
private final class LyricsMoveButton: NSButton {
    var onDragStart: ((NSEvent) -> Void)?
    var onDrag: ((NSEvent) -> Void)?
    var onDragEnd: (() -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onDragStart?(event)
    }
    override func mouseDragged(with event: NSEvent) { onDrag?(event) }
    override func mouseUp(with event: NSEvent) { onDragEnd?() }
}

/// Adds interaction to the existing renderer; no lyric selection or playback clock lives here.
@MainActor
final class FreeLyricsInteraction: NSObject {
    static let toolbarHeight: CGFloat = 38
    static let expandedToolbarWidth: CGFloat = 188
    let window: NSWindow
    private let lyricViews: [NSView]
    private let container: NSView
    private let unlockWindow = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let defaults: UserDefaults
    private let toolbar = FreeLyricsHoverView()
    private let moveButton = LyricsMoveButton()
    private let lockButton = NSButton()
    private let orientationButton = NSButton()
    private let colorButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private var policy = FreeLyricsPolicy()
    private var hovered = false
    private var hoverTimer: Timer?
    private var exitWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var vertical = false
    private var requestedSize = NSSize(width: 440, height: 80)
    private var dragging = false
    private var dragStart = NSPoint.zero
    private var dragOrigin = NSPoint.zero
    var onSettings: (() -> Void)?
    var onClose: (() -> Void)?
    var onColor: (() -> Void)?
    var onInteractionChanged: (() -> Void)?
    var isEditing: Bool { policy.editing }

    init(window: NSWindow, container: NSView, lyricViews: [NSView], defaults: UserDefaults = .standard) {
        self.window = window
        self.container = container
        self.defaults = defaults
        self.lyricViews = lyricViews
        super.init()
        unlockWindow.isOpaque = false
        unlockWindow.backgroundColor = .clear
        unlockWindow.hasShadow = false
        unlockWindow.hidesOnDeactivate = false
        unlockWindow.isReleasedWhenClosed = false
        unlockWindow.level = window.level
        unlockWindow.collectionBehavior = window.collectionBehavior
        unlockWindow.title = L10n.text("Unlock Position")
        window.addChildWindow(unlockWindow, ordered: .above)
        toolbar.material = .hudWindow
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 10
        toolbar.layer?.masksToBounds = true
        toolbar.onHover = { [weak self] in self?.setHovered($0) }
        container.addSubview(toolbar)
        configure(moveButton, symbol: "arrow.up.and.down.and.arrow.left.and.right", label: "Move Lyrics", action: nil)
        moveButton.onDragStart = { [weak self] event in self?.beginDrag(with: event) }
        moveButton.onDrag = { [weak self] event in self?.continueDrag(with: event) }
        moveButton.onDragEnd = { [weak self] in self?.endDrag() }
        colorButton.addItem(withTitle: L10n.text("Lyrics Color"))
        colorButton.item(at: 0)?.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: L10n.text("Lyrics Color"))
        for preset in [LyricsColorPreset.white, .orange, .blue, .purple, .green, .mintGradient] {
            colorButton.addItem(withTitle: L10n.text(preset.rawValue))
            colorButton.lastItem?.representedObject = preset.rawValue
        }
        colorButton.isBordered = false
        colorButton.target = self
        colorButton.action = #selector(changeColor)
        colorButton.toolTip = L10n.text("Lyrics Color")
        colorButton.setAccessibilityLabel(L10n.text("Lyrics Color"))
        toolbar.addSubview(colorButton)
        let settings = NSButton()
        configure(settings, symbol: "gearshape", label: "Open NotchMuse", action: #selector(openSettings))
        let close = NSButton()
        configure(close, symbol: "xmark", label: "Hide Lyrics", action: #selector(closeLyrics))
        configure(lockButton, symbol: "lock.open", label: "Lock Position", action: #selector(toggleLock))
        configure(orientationButton, symbol: "rectangle.portrait", label: "Switch to Vertical", action: #selector(toggleOrientation))
        toolbar.alphaValue = 0
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector?) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: L10n.text(label))
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.toolTip = L10n.text(label)
        button.setAccessibilityLabel(L10n.text(label))
        button.target = self
        button.action = action
        toolbar.addSubview(button)
    }

    static func screenID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return screen.localizedName }
        return CFUUIDCreateString(nil, uuid) as String
    }

    func screen(vertical: Bool, fallback: NSScreen) -> NSScreen {
        let screens = NSScreen.screens
        let index = FreeLyricsGeometry.screenIndex(savedID: FreeLyricsPreferences.load(vertical: vertical, defaults: defaults)?.screenID,
            screenIDs: screens.map(Self.screenID), preferredIndex: screens.firstIndex(of: fallback) ?? 0)
        return index.map { screens[$0] } ?? fallback
    }

    func frame(size: NSSize, vertical: Bool, fallback: NSScreen) -> NSRect {
        self.vertical = vertical
        requestedSize = size
        if dragging { return window.frame }
        var anchor = FreeLyricsPreferences.load(vertical: vertical, defaults: defaults)
        let screen = screen(vertical: vertical, fallback: fallback)
        let frame = FreeLyricsGeometry.frame(anchor: anchor, size: size, visible: screen.visibleFrame)
        if anchor == nil {
            anchor = FreeLyricsGeometry.anchor(frame: frame, visible: screen.visibleFrame, screenID: Self.screenID(screen))
            FreeLyricsPreferences.save(anchor!, vertical: vertical, defaults: defaults)
        }
        return frame
    }

    func update(hideOnHover: Bool) {
        policy.locked = defaults.bool(forKey: FreeLyricsPreferences.lockedKey)
        policy.passThrough = defaults.bool(forKey: FreeLyricsPreferences.passThroughKey)
        policy.hideOnHover = hideOnHover
        let unlocked = policy.editing || !policy.locked
        // Returning nil from a view hit-test does not pass an event to a window behind it.
        // The locked lyric window ignores events; only the small child panel receives unlock clicks.
        window.ignoresMouseEvents = policy.ignoresMouseEvents || !unlocked
        unlockWindow.ignoresMouseEvents = policy.ignoresMouseEvents
        moveButton.isEnabled = policy.canMove
        let lockAction = L10n.text(unlocked ? "Lock Position" : "Unlock Position")
        lockButton.image = NSImage(systemSymbolName: unlocked ? "lock.open" : "lock", accessibilityDescription: lockAction)
        lockButton.toolTip = lockAction
        lockButton.setAccessibilityLabel(lockAction)
        let orientationAction = L10n.text(defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "Switch to Horizontal" : "Switch to Vertical")
        orientationButton.toolTip = orientationAction
        orientationButton.setAccessibilityLabel(orientationAction)
        orientationButton.image = NSImage(systemSymbolName: defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "rectangle" : "rectangle.portrait", accessibilityDescription: orientationAction)
        let controls = [moveButton, colorButton, lockButton, orientationButton, toolbar.subviews[2], toolbar.subviews[3]]
        let width: CGFloat = unlocked ? Self.expandedToolbarWidth : 38
        if unlocked {
            unlockWindow.orderOut(nil)
            if toolbar.superview !== container {
                unlockWindow.contentView = nil
                container.addSubview(toolbar)
            }
            toolbar.frame = NSRect(x: (window.frame.width - width) / 2, y: 3, width: width, height: 32)
        } else {
            if unlockWindow.contentView !== toolbar {
                toolbar.removeFromSuperview()
                unlockWindow.contentView = toolbar
            }
            toolbar.frame = NSRect(x: 0, y: 0, width: width, height: 32)
            positionUnlockWindow()
        }
        for (index, child) in controls.enumerated() {
            child.isHidden = !unlocked && child !== lockButton
            child.frame = NSRect(x: unlocked ? 4 + CGFloat(index) * 30 : 4, y: 1, width: 30, height: 30)
        }
        // Position-only polling also works when the entire window intentionally ignores events.
        // No event tap, permission, or global mouse-event interception is required.
        if hoverTimer == nil {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.window.isVisible else { return }
                    self.setHovered(self.window.frame.contains(NSEvent.mouseLocation))
                }
            }
        }
        applyVisibility(animated: false)
    }

    func beginEditing() {
        defaults.set(false, forKey: FreeLyricsPreferences.lockedKey)
        policy.editing = true
        update(hideOnHover: policy.hideOnHover)
    }

    @objc func endEditing() {
        policy.editing = false
        update(hideOnHover: policy.hideOnHover)
        onInteractionChanged?()
    }

    @objc private func toggleLock() {
        let locking = policy.editing || !policy.locked
        defaults.set(locking, forKey: FreeLyricsPreferences.lockedKey)
        if locking {
            endEditing()
        } else {
            beginEditing()
            onInteractionChanged?()
        }
    }

    @objc private func toggleOrientation() {
        defaults.set(!defaults.bool(forKey: FreeLyricsPreferences.verticalKey), forKey: FreeLyricsPreferences.verticalKey)
        update(hideOnHover: policy.hideOnHover)
        onInteractionChanged?()
    }

    private func beginDrag(with event: NSEvent) {
        guard policy.canMove else { return }
        beginEditing()
        dragging = true
        applyVisibility(animated: false)
        dragStart = window.convertPoint(toScreen: event.locationInWindow)
        dragOrigin = window.frame.origin
    }

    private func continueDrag(with event: NSEvent) {
        guard dragging else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        window.setFrameOrigin(NSPoint(x: dragOrigin.x + point.x - dragStart.x, y: dragOrigin.y + point.y - dragStart.y))
    }

    private func endDrag() {
        guard dragging else { return }
        dragging = false
        savePosition()
        // AppKit responder events only: no event tap or global mouse interception.
        // Locking restores stored hover/pass-through preferences; controls still follow hover.
        applyVisibility(animated: false)
    }

    func savePosition() {
        if let screen = window.screen ?? NSScreen.main {
            let anchor = FreeLyricsGeometry.anchor(frame: window.frame, visible: screen.visibleFrame, screenID: Self.screenID(screen))
            FreeLyricsPreferences.save(anchor, vertical: vertical, defaults: defaults)
            window.setFrame(FreeLyricsGeometry.frame(anchor: anchor, size: requestedSize, visible: screen.visibleFrame), display: true)
        }
    }

    private func setHovered(_ value: Bool) {
        if value {
            exitWork?.cancel()
            exitWork = nil
            guard !hovered else { return }
            hovered = true
            applyVisibility(animated: true)
        } else if hovered && exitWork == nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hovered = false
                self.exitWork = nil
                self.applyVisibility(animated: true)
            }
            exitWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }

    private func applyVisibility(animated: Bool) {
        let lyricsAlpha: CGFloat = policy.hidesLyrics(hovered: hovered) ? 0 : 1
        let toolbarAlpha: CGFloat = (hovered || dragging) && !policy.ignoresMouseEvents ? 1 : 0
        if policy.locked && !policy.editing && toolbarAlpha > 0 && window.isVisible {
            if !unlockWindow.isVisible { unlockWindow.orderFrontRegardless() }
        } else {
            unlockWindow.orderOut(nil)
        }
        // Do not restart an in-flight fade on each lyric-progress update.
        guard lyricViews.contains(where: { $0.alphaValue != lyricsAlpha }) || toolbar.alphaValue != toolbarAlpha else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.14 : 0
            for view in lyricViews { view.animator().alphaValue = lyricsAlpha }
            toolbar.animator().alphaValue = toolbarAlpha
        }
    }

    private func positionUnlockWindow() {
        let frame = window.convertToScreen(NSRect(x: (window.frame.width - 38) / 2, y: 3, width: 38, height: 32))
        if unlockWindow.frame != frame { unlockWindow.setFrame(frame, display: true) }
    }

    private func reposition() {
        guard window.isVisible, !dragging, let screen = window.screen ?? NSScreen.main else { return }
        window.setFrame(frame(size: requestedSize, vertical: vertical, fallback: screen), display: true)
        positionUnlockWindow()
    }

    func hide() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        exitWork?.cancel()
        exitWork = nil
        hovered = false
        policy.editing = false
        dragging = false
        applyVisibility(animated: false)
    }

    #if DEBUG
    func testHover(_ hovered: Bool) {
        exitWork?.cancel()
        exitWork = nil
        self.hovered = hovered
        applyVisibility(animated: false)
    }
    var testToolbar: NSView { toolbar }
    var testUnlockWindow: NSWindow { unlockWindow }
    #endif

    @objc private func changeColor() {
        guard let raw = colorButton.selectedItem?.representedObject as? String else { return }
        defaults.set(raw, forKey: AppPreferences.colorPresetKey)
        onColor?()
    }
    @objc private func openSettings() { onSettings?() }
    @objc private func closeLyrics() { hide(); onClose?() }
}
