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

enum FreeLyricsSnap {
    static let threshold: CGFloat = 10
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 12

    struct Result: Equatable {
        let origin: NSPoint
        let snappedCenterX: Bool
        let snappedEdge: Bool
        var snappedAny: Bool { snappedCenterX || snappedEdge }
    }

    static func snappedOrigin(
        proposed: NSPoint,
        size: NSSize,
        visible: NSRect,
        bypass: Bool = false
    ) -> Result {
        let maxX = max(visible.minX, visible.maxX - size.width)
        let maxY = max(visible.minY, visible.maxY - size.height)
        var x = min(max(proposed.x, visible.minX), maxX)
        var y = min(max(proposed.y, visible.minY), maxY)
        var snappedCenterX = false
        var snappedEdge = false

        if !bypass {
            let centerX = visible.midX - size.width / 2
            let leftEdge = min(maxX, visible.minX + horizontalInset)
            let rightEdge = max(visible.minX, visible.maxX - horizontalInset - size.width)
            let bottomEdge = min(maxY, visible.minY + verticalInset)
            let topEdge = max(visible.minY, visible.maxY - verticalInset - size.height)

            if abs(x - centerX) <= threshold {
                x = centerX
                snappedCenterX = true
            } else if abs(x - leftEdge) <= threshold {
                x = leftEdge
                snappedEdge = true
            } else if abs(x - rightEdge) <= threshold {
                x = rightEdge
                snappedEdge = true
            }

            if abs(y - bottomEdge) <= threshold {
                y = bottomEdge
                snappedEdge = true
            } else if abs(y - topEdge) <= threshold {
                y = topEdge
                snappedEdge = true
            }
        }
        return Result(origin: NSPoint(x: x, y: y), snappedCenterX: snappedCenterX, snappedEdge: snappedEdge)
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
private final class PillIconButton: NSButton {
    private var tracking: NSTrackingArea?
    private var isPointerInside = false {
        didSet {
            layer?.backgroundColor = isPointerInside ? NSColor.white.withAlphaComponent(0.14).cgColor : NSColor.clear.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isPointerInside = true }
    override func mouseExited(with event: NSEvent) { isPointerInside = false }
}

@MainActor
final class FreeLyricsDragSurfaceView: NSView {
    var isDragEnabled = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    var isDraggingNow = false {
        didSet {
            layer?.borderColor = isDraggingNow ? NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor : NSColor.clear.cgColor
            layer?.backgroundColor = isDraggingNow ? NSColor.black.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
            window?.invalidateCursorRects(for: self)
        }
    }
    var onDragStart: ((NSEvent) -> Void)?
    var onDrag: ((NSEvent) -> Void)?
    var onDragEnd: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isDragEnabled else { return }
        addCursorRect(bounds, cursor: isDraggingNow ? .closedHand : .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard isDragEnabled else { return }
        onDragStart?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}

@MainActor
private final class CenterSnapGuideView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.midX, y: 0))
        path.line(to: NSPoint(x: bounds.midX, y: bounds.maxY))
        path.lineWidth = 1
        let pattern: [CGFloat] = [5, 5]
        path.setLineDash(pattern, count: pattern.count, phase: 0)
        NSColor.white.withAlphaComponent(0.28).setStroke()
        path.stroke()
    }
}

/// Adds interaction to the existing renderer; no lyric selection or playback clock lives here.
@MainActor
final class FreeLyricsInteraction: NSObject {
    static let toolbarHeight: CGFloat = 38
    static let expandedToolbarWidth: CGFloat = 176
    let window: NSWindow
    private let lyricViews: [NSView]
    private let container: NSView
    private let dragSurface = FreeLyricsDragSurfaceView()
    private let unlockWindow = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let snapGuideWindow = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let defaults: UserDefaults
    private let toolbar = FreeLyricsHoverView()
    private let lockButton = PillIconButton()
    private let orientationButton = PillIconButton()
    private let colorButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private let settingsButton = PillIconButton()
    private let closeButton = PillIconButton()
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
    private var wasSnapped = false
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

        dragSurface.autoresizingMask = [.width, .height]
        dragSurface.onDragStart = { [weak self] event in self?.beginDrag(with: event) }
        dragSurface.onDrag = { [weak self] event in self?.continueDrag(with: event) }
        dragSurface.onDragEnd = { [weak self] in self?.endDrag() }
        container.addSubview(dragSurface)

        unlockWindow.isOpaque = false
        unlockWindow.backgroundColor = .clear
        unlockWindow.hasShadow = false
        unlockWindow.hidesOnDeactivate = false
        unlockWindow.isReleasedWhenClosed = false
        unlockWindow.level = window.level
        unlockWindow.collectionBehavior = window.collectionBehavior
        unlockWindow.title = L10n.text("Unlock Position")
        window.addChildWindow(unlockWindow, ordered: .above)

        snapGuideWindow.isOpaque = false
        snapGuideWindow.backgroundColor = .clear
        snapGuideWindow.hasShadow = false
        snapGuideWindow.ignoresMouseEvents = true
        snapGuideWindow.hidesOnDeactivate = false
        snapGuideWindow.isReleasedWhenClosed = false
        snapGuideWindow.level = window.level
        snapGuideWindow.collectionBehavior = window.collectionBehavior
        snapGuideWindow.contentView = CenterSnapGuideView()

        toolbar.material = .hudWindow
        toolbar.blendingMode = .behindWindow
        toolbar.state = .active
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 17
        toolbar.layer?.cornerCurve = .continuous
        toolbar.layer?.borderWidth = 0.5
        toolbar.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        toolbar.layer?.masksToBounds = true
        toolbar.onHover = { [weak self] in self?.setHovered($0) }
        container.addSubview(toolbar)

        configure(lockButton, symbol: "lock.open", label: "Lock Position", action: #selector(toggleLock))
        configure(orientationButton, symbol: "rectangle.portrait", label: "Switch to Vertical", action: #selector(toggleOrientation))
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
        configure(settingsButton, symbol: "gearshape", label: "Open NotchMuse", action: #selector(openSettings))
        configure(closeButton, symbol: "xmark", label: "Hide Lyrics", action: #selector(closeLyrics))
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
        window.ignoresMouseEvents = policy.ignoresMouseEvents || !unlocked
        unlockWindow.ignoresMouseEvents = policy.ignoresMouseEvents
        dragSurface.isDragEnabled = policy.canMove
        dragSurface.frame = NSRect(x: 0, y: Self.toolbarHeight, width: container.bounds.width, height: max(0, container.bounds.height - Self.toolbarHeight))

        let lockAction = L10n.text(unlocked ? "Lock Position" : "Unlock Position")
        lockButton.image = NSImage(systemSymbolName: unlocked ? "lock.open" : "lock", accessibilityDescription: lockAction)
        lockButton.toolTip = lockAction
        lockButton.setAccessibilityLabel(lockAction)
        let orientationAction = L10n.text(defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "Switch to Horizontal" : "Switch to Vertical")
        orientationButton.toolTip = orientationAction
        orientationButton.setAccessibilityLabel(orientationAction)
        orientationButton.image = NSImage(systemSymbolName: defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "rectangle" : "rectangle.portrait", accessibilityDescription: orientationAction)

        let controls: [NSView] = [lockButton, orientationButton, colorButton, settingsButton, closeButton]
        let width: CGFloat = unlocked ? Self.expandedToolbarWidth : 38
        let height: CGFloat = 34
        if unlocked {
            unlockWindow.orderOut(nil)
            if toolbar.superview !== container {
                unlockWindow.contentView = nil
                container.addSubview(toolbar)
            }
            toolbar.frame = NSRect(x: (window.frame.width - width) / 2, y: 2, width: width, height: height)
        } else {
            if unlockWindow.contentView !== toolbar {
                toolbar.removeFromSuperview()
                unlockWindow.contentView = toolbar
            }
            toolbar.frame = NSRect(x: 0, y: 0, width: width, height: height)
            positionUnlockWindow()
        }
        for (index, child) in controls.enumerated() {
            child.isHidden = !unlocked && child !== lockButton
            child.frame = NSRect(x: unlocked ? 6 + CGFloat(index) * 34 : 5, y: 3, width: 28, height: 28)
        }
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
        wasSnapped = false
        dragSurface.isDraggingNow = true
        NSCursor.closedHand.push()
        applyVisibility(animated: false)
        dragStart = window.convertPoint(toScreen: event.locationInWindow)
        dragOrigin = window.frame.origin
    }

    private func continueDrag(with event: NSEvent) {
        guard dragging else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        let proposed = NSPoint(x: dragOrigin.x + point.x - dragStart.x, y: dragOrigin.y + point.y - dragStart.y)
        let bypass = event.modifierFlags.contains(.option)
        if let screen = window.screen ?? NSScreen.main {
            let snapped = FreeLyricsSnap.snappedOrigin(
                proposed: proposed,
                size: window.frame.size,
                visible: screen.visibleFrame,
                bypass: bypass
            )
            window.setFrameOrigin(snapped.origin)
            if snapped.snappedAny && !wasSnapped {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            wasSnapped = snapped.snappedAny
            if snapped.snappedCenterX {
                let guideFrame = NSRect(x: screen.visibleFrame.midX - 1, y: screen.visibleFrame.minY, width: 2, height: screen.visibleFrame.height)
                if snapGuideWindow.frame != guideFrame { snapGuideWindow.setFrame(guideFrame, display: true) }
                if !snapGuideWindow.isVisible { snapGuideWindow.orderFrontRegardless() }
            } else {
                snapGuideWindow.orderOut(nil)
            }
        } else {
            window.setFrameOrigin(proposed)
        }
    }

    private func endDrag() {
        guard dragging else { return }
        dragging = false
        wasSnapped = false
        dragSurface.isDraggingNow = false
        NSCursor.pop()
        snapGuideWindow.orderOut(nil)
        savePosition()
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
        guard lyricViews.contains(where: { $0.alphaValue != lyricsAlpha }) || toolbar.alphaValue != toolbarAlpha else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.14 : 0
            for view in lyricViews { view.animator().alphaValue = lyricsAlpha }
            toolbar.animator().alphaValue = toolbarAlpha
        }
    }

    private func positionUnlockWindow() {
        let frame = window.convertToScreen(NSRect(x: (window.frame.width - 38) / 2, y: 2, width: 38, height: 34))
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
        wasSnapped = false
        dragSurface.isDraggingNow = false
        snapGuideWindow.orderOut(nil)
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
    var testDragSurface: FreeLyricsDragSurfaceView { dragSurface }
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
