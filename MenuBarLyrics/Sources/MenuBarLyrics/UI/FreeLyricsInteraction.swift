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

enum FreeLyricsLineMode: String, CaseIterable, Sendable {
    case single = "Single"
    case double = "Double"
}

enum FreeLyricsPreferences {
    static let verticalKey = "FreeLyricsVertical"
    static let lockedKey = "FreeLyricsLocked"
    static let passThroughKey = "FreeLyricsPassThrough"
    static let lineModeKey = "FreeLyricsLineMode"
    static let horizontalAnchorKey = "FreeLyricsHorizontalAnchor"
    static let verticalAnchorKey = "FreeLyricsVerticalAnchor"
    static let keys = [verticalKey, lockedKey, passThroughKey, lineModeKey, horizontalAnchorKey, verticalAnchorKey]
    static var vertical: Bool { UserDefaults.standard.bool(forKey: verticalKey) }
    static var lineMode: FreeLyricsLineMode { lineMode(in: .standard) }
    static func lineMode(in defaults: UserDefaults) -> FreeLyricsLineMode {
        FreeLyricsLineMode(rawValue: defaults.string(forKey: lineModeKey) ?? "") ?? .single
    }
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
    var onHoverChange: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?
    private var isPointerInside = false {
        didSet {
            if isPointerInside != oldValue {
                layer?.backgroundColor = isPointerInside ? NSColor.white.withAlphaComponent(0.14).cgColor : NSColor.clear.cgColor
                onHoverChange?(isPointerInside)
            }
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
    private let highlightLayer = CALayer()
    private(set) var tightContentRect: NSRect = .zero
    private(set) var hasCapsuleBackground = false

    var isDragEnabled = false {
        didSet {
            updateSurfaceStyle()
            window?.invalidateCursorRects(for: self)
        }
    }
    var isHoveredNow = false {
        didSet {
            if isHoveredNow != oldValue { updateSurfaceStyle() }
        }
    }
    var isDraggingNow = false {
        didSet {
            if isDraggingNow != oldValue {
                updateSurfaceStyle()
                window?.invalidateCursorRects(for: self)
            }
        }
    }
    var onDragStart: ((NSEvent) -> Void)?
    var onDrag: ((NSEvent) -> Void)?
    var onDragEnd: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        highlightLayer.cornerRadius = 14
        highlightLayer.cornerCurve = .continuous
        highlightLayer.borderWidth = 0.75
        highlightLayer.borderColor = NSColor.clear.cgColor
        highlightLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(highlightLayer)
    }

    required init?(coder: NSCoder) { nil }

    func updateContentLayout(rect: NSRect, hasCapsuleBackground: Bool) {
        self.tightContentRect = rect
        self.hasCapsuleBackground = hasCapsuleBackground
        updateSurfaceStyle()
    }

    override func layout() {
        super.layout()
        updateSurfaceStyle()
    }

    var activeHighlightFrame: NSRect {
        let candidate = tightContentRect.isEmpty ? bounds : tightContentRect
        let clampedW = min(bounds.width, max(60, candidate.width))
        let clampedH = min(bounds.height, max(28, candidate.height))
        let x = min(max(0, candidate.minX), max(0, bounds.width - clampedW))
        let y = min(max(0, candidate.minY), max(0, bounds.height - clampedH))
        return NSRect(x: x, y: y, width: clampedW, height: clampedH)
    }

    private func updateSurfaceStyle() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.14)
        let targetFrame = activeHighlightFrame
        highlightLayer.frame = targetFrame
        highlightLayer.cornerRadius = min(16, targetFrame.height / 2)
        if isDragEnabled && (isHoveredNow || isDraggingNow) {
            if hasCapsuleBackground {
                // Never draw a second gray box behind an existing capsule; highlight with crisp 1.5pt warm amber border
                highlightLayer.backgroundColor = NSColor.clear.cgColor
                highlightLayer.borderWidth = 1.5
                highlightLayer.borderColor = NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: isDraggingNow ? 0.92 : 0.75).cgColor
            } else {
                let alpha: CGFloat = isDraggingNow ? 0.54 : 0.40
                highlightLayer.backgroundColor = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: alpha).cgColor
                highlightLayer.borderWidth = 0.75
                highlightLayer.borderColor = NSColor.white.withAlphaComponent(isDraggingNow ? 0.24 : 0.14).cgColor
            }
        } else {
            highlightLayer.backgroundColor = NSColor.clear.cgColor
            highlightLayer.borderColor = NSColor.clear.cgColor
        }
        CATransaction.commit()
    }

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

@MainActor
private final class QuickColorDotButton: NSButton {
    let swatchColors: [NSColor]
    let preset: LyricsColorPreset
    let customStartColor: NSColor?
    let customEndColor: NSColor?
    private var isHovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(
        title: String,
        swatchColors: [NSColor],
        preset: LyricsColorPreset,
        customStartColor: NSColor? = nil,
        customEndColor: NSColor? = nil,
        target: AnyObject?,
        action: Selector?
    ) {
        self.swatchColors = swatchColors
        self.preset = preset
        self.customStartColor = customStartColor
        self.customEndColor = customEndColor
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.toolTip = title
        self.setAccessibilityLabel(title)
        self.target = target
        self.action = action
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 22),
            heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = isHovered ? 2.0 : 3.0
        let dotRect = bounds.insetBy(dx: inset, dy: inset)
        let circle = NSBezierPath(ovalIn: dotRect)
        if swatchColors.count >= 2, let gradient = NSGradient(colors: swatchColors) {
            NSGraphicsContext.saveGraphicsState()
            circle.addClip()
            gradient.draw(in: dotRect, angle: -45)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            (swatchColors.first ?? .white).setFill()
            circle.fill()
        }
        NSColor.white.withAlphaComponent(isHovered ? 0.78 : 0.28).setStroke()
        circle.lineWidth = isHovered ? 1.5 : 0.75
        circle.stroke()
    }
}

@MainActor
private final class QuickColorPopoverController: NSViewController {
    static let curatedGradientCount = 3
    private let onPick: (LyricsColorPreset, NSColor?, NSColor?) -> Void

    init(onPick: @escaping (LyricsColorPreset, NSColor?, NSColor?) -> Void) {
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let isZh = AppPreferences.language == .simplifiedChinese
        let solids: [(String, NSColor, LyricsColorPreset, NSColor?)] = [
            (isZh ? "纯白" : "Pure White", .white, .white, nil),
            (isZh ? "暖琥珀" : "Warm Amber", NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1), .orange, nil),
            (isZh ? "天青蓝" : "Sky Blue", NSColor(calibratedRed: 0.220, green: 0.741, blue: 0.973, alpha: 1), .blue, nil),
            (isZh ? "翡翠绿" : "Emerald Green", NSColor(calibratedRed: 0.204, green: 0.827, blue: 0.600, alpha: 1), .green, nil),
            (isZh ? "樱花粉" : "Sakura Pink", NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.66, alpha: 1), .custom, NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.66, alpha: 1)),
            (isZh ? "柔紫" : "Soft Purple", NSColor(calibratedRed: 0.72, green: 0.54, blue: 0.96, alpha: 1), .purple, nil),
            (isZh ? "墨黑" : "Ink Black", NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1), .custom, NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        ]
        let gradients: [(String, NSColor, NSColor)] = [
            (isZh ? "暖日落橙粉" : "Warm Sunset",
             NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1),
             NSColor(calibratedRed: 1.0, green: 0.302, blue: 0.553, alpha: 1)),
            (isZh ? "极光青紫" : "Aurora Sky",
             NSColor(calibratedRed: 0.220, green: 0.741, blue: 0.973, alpha: 1),
             NSColor(calibratedRed: 0.659, green: 0.333, blue: 0.969, alpha: 1)),
            (isZh ? "薄荷晴空" : "Mint Breeze",
             NSColor(calibratedRed: 0.204, green: 0.827, blue: 0.600, alpha: 1),
             NSColor(calibratedRed: 0.055, green: 0.647, blue: 0.914, alpha: 1))
        ]

        var views: [NSView] = solids.map { entry in
            QuickColorDotButton(
                title: entry.0,
                swatchColors: [entry.1],
                preset: entry.2,
                customStartColor: entry.3,
                target: self,
                action: #selector(dotClicked(_:))
            )
        }
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 14)
        ])
        views.append(divider)
        views.append(contentsOf: gradients.map { entry in
            QuickColorDotButton(
                title: entry.0,
                swatchColors: [entry.1, entry.2],
                preset: .customGradient,
                customStartColor: entry.1,
                customEndColor: entry.2,
                target: self,
                action: #selector(dotClicked(_:))
            )
        })

        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 302, height: 38))
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        self.view = root
    }

    @objc private func dotClicked(_ sender: NSButton) {
        guard let dot = sender as? QuickColorDotButton else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        onPick(dot.preset, dot.customStartColor, dot.customEndColor)
    }
}

@MainActor
private final class FloatingToolbarHintPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        let bg = NSVisualEffectView()
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 6
        bg.layer?.cornerCurve = .continuous
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        bg.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: bg.centerYAnchor)
        ])
        contentView = bg
    }

    func show(text: String, above anchorScreenRect: NSRect, screenVisible: NSRect, level: NSWindow.Level) {
        guard !text.isEmpty else { orderOut(nil); return }
        self.level = level
        label.stringValue = text
        let textW = ceil((text as NSString).size(withAttributes: [.font: label.font!]).width)
        let w = textW + 18
        let h: CGFloat = 22
        let x = min(max(screenVisible.minX + 6, anchorScreenRect.midX - w / 2), screenVisible.maxX - w - 6)
        let y = min(screenVisible.maxY - h - 4, anchorScreenRect.maxY + 6)
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1
        }
    }
}

/// Adds interaction to the existing renderer; no lyric selection or playback clock lives here.
@MainActor
final class FreeLyricsInteraction: NSObject {
    static let toolbarHeight: CGFloat = 38
    static let expandedToolbarWidth: CGFloat = 212
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
    private let colorButton = PillIconButton()
    private let mainWindowButton = PillIconButton()
    private let settingsButton = PillIconButton()
    private let closeButton = PillIconButton()
    private var colorPopover: NSPopover?
    private let hintPanel = FloatingToolbarHintPanel()
    private var hintWork: DispatchWorkItem?
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
    var onOpenMainWindow: (() -> Void)?
    var onSettings: (() -> Void)?
    var onClose: (() -> Void)?
    var onColor: (() -> Void)?
    var onInteractionChanged: (() -> Void)?
    var isEditing: Bool { policy.editing }

    /// Toolbar defaults ABOVE the lyrics so dragging down to the Dock is unobstructed;
    /// flips below only when the window is pinned near the very top of the screen.
    var isToolbarAbove: Bool {
        guard let screen = window.screen ?? NSScreen.main else { return true }
        return (screen.visibleFrame.maxY - window.frame.maxY) >= 10
    }

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
        configure(colorButton, symbol: "paintpalette", label: "Quick Colors", action: #selector(toggleQuickColorPopover))
        configure(mainWindowButton, symbol: "music.note.list", label: "Open Main Window", action: #selector(openMainWindow))
        configure(settingsButton, symbol: "gearshape", label: "Preferences", action: #selector(openSettings))
        configure(closeButton, symbol: "xmark", label: "Hide Lyrics", action: #selector(closeLyrics))
        toolbar.alphaValue = 0

        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    private func configure(_ button: PillIconButton, symbol: String, label: String, action: Selector?) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: L10n.text(label))
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.toolTip = L10n.text(label)
        button.setAccessibilityLabel(L10n.text(label))
        button.target = self
        button.action = action
        button.onHoverChange = { [weak self, weak button] entered in
            guard let self, let button else { return }
            if entered {
                self.scheduleHint(for: button)
            } else {
                self.hideHint()
            }
        }
        toolbar.addSubview(button)
    }

    func updateContentLayout(rect: NSRect, hasCapsuleBackground: Bool) {
        dragSurface.updateContentLayout(rect: rect, hasCapsuleBackground: hasCapsuleBackground)
    }

    private func scheduleHint(for button: NSButton) {
        hintWork?.cancel()
        let text = button.toolTip ?? ""
        guard !text.isEmpty else { return }
        let work = DispatchWorkItem { [weak self, weak button] in
            guard let self, let button, let btnWindow = button.window, btnWindow.isVisible else { return }
            let rectInWindow = button.convert(button.bounds, to: nil)
            let screenRect = btnWindow.convertToScreen(rectInWindow)
            let visible = (btnWindow.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            self.hintPanel.show(text: button.toolTip ?? text, above: screenRect, screenVisible: visible, level: btnWindow.level)
        }
        hintWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func hideHint() {
        hintWork?.cancel()
        hintWork = nil
        hintPanel.orderOut(nil)
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
        let above = isToolbarAbove
        dragSurface.isDragEnabled = policy.canMove
        dragSurface.frame = NSRect(
            x: 0,
            y: above ? 0 : Self.toolbarHeight,
            width: container.bounds.width,
            height: max(0, container.bounds.height - Self.toolbarHeight)
        )

        let lockAction = L10n.text(unlocked ? "Lock Position / Click-Through" : "Unlock Position")
        lockButton.image = NSImage(systemSymbolName: unlocked ? "lock.open" : "lock", accessibilityDescription: lockAction)
        lockButton.toolTip = lockAction
        lockButton.setAccessibilityLabel(lockAction)
        let orientationAction = L10n.text(defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "Switch to Horizontal" : "Switch to Vertical")
        orientationButton.toolTip = orientationAction
        orientationButton.setAccessibilityLabel(orientationAction)
        orientationButton.image = NSImage(systemSymbolName: defaults.bool(forKey: FreeLyricsPreferences.verticalKey) ? "rectangle" : "rectangle.portrait", accessibilityDescription: orientationAction)
        colorButton.toolTip = L10n.text("Quick Colors")
        mainWindowButton.toolTip = L10n.text("Open Main Window")
        settingsButton.toolTip = L10n.text("Preferences")
        closeButton.toolTip = L10n.text("Hide Lyrics")

        let controls: [NSView] = [lockButton, orientationButton, colorButton, mainWindowButton, settingsButton, closeButton]
        let width: CGFloat = unlocked ? Self.expandedToolbarWidth : 38
        let height: CGFloat = 34
        let toolbarY: CGFloat = above ? max(2, container.bounds.height - Self.toolbarHeight + 2) : 2
        if unlocked {
            unlockWindow.orderOut(nil)
            if toolbar.superview !== container {
                unlockWindow.contentView = nil
                container.addSubview(toolbar)
            }
            toolbar.frame = NSRect(x: (window.frame.width - width) / 2, y: toolbarY, width: width, height: height)
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
        let popoverShown = colorPopover?.isShown == true
        let toolbarAlpha: CGFloat = (hovered || dragging || popoverShown) && !policy.ignoresMouseEvents ? 1 : 0
        dragSurface.isHoveredNow = (hovered || popoverShown) && !policy.ignoresMouseEvents
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
        let y: CGFloat = isToolbarAbove ? max(2, window.frame.height - Self.toolbarHeight + 2) : 2
        let frame = window.convertToScreen(NSRect(x: (window.frame.width - 38) / 2, y: y, width: 38, height: 34))
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
        hideHint()
        colorPopover?.close()
        colorPopover = nil
        hovered = false
        policy.editing = false
        dragging = false
        wasSnapped = false
        dragSurface.isHoveredNow = false
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
    static var testCuratedGradientCount: Int { QuickColorPopoverController.curatedGradientCount }
    #endif

    func selectQuickColorPreset(_ preset: LyricsColorPreset, customColor: NSColor? = nil, customEndColor: NSColor? = nil) {
        defaults.set(preset.rawValue, forKey: AppPreferences.colorPresetKey)
        if let customColor {
            AppPreferences.setColor(customColor, forKey: AppPreferences.customLyricsColorKey, in: defaults)
        }
        if let customEndColor {
            AppPreferences.setColor(customEndColor, forKey: AppPreferences.customLyricsEndColorKey, in: defaults)
        }
        colorPopover?.close()
        colorPopover = nil
        onColor?()
    }

    @objc private func toggleQuickColorPopover() {
        hideHint()
        if let existing = colorPopover, existing.isShown {
            existing.close()
            colorPopover = nil
            return
        }
        let vc = QuickColorPopoverController { [weak self] preset, customStart, customEnd in
            self?.selectQuickColorPreset(preset, customColor: customStart, customEndColor: customEnd)
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = vc
        popover.contentSize = NSSize(width: 302, height: 38)
        popover.show(relativeTo: colorButton.bounds, of: colorButton, preferredEdge: isToolbarAbove ? .maxY : .minY)
        colorPopover = popover
    }

    @objc private func openMainWindow() { onOpenMainWindow?() }
    @objc private func openSettings() { onSettings?() }
    @objc private func closeLyrics() { hide(); onClose?() }
}
