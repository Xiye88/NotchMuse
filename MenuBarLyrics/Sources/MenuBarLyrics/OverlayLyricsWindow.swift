import AppKit
import QuartzCore

enum DisplayMode: String, CaseIterable {
    case statusBar = "Status Bar"
    case notch = "Notch Mode"
}

enum LyricsPosition: String, CaseIterable {
    case left = "Left"
    case right = "Right"

    var menuTitle: String {
        L10n.text(rawValue)
    }
}

enum NotchStyle: String, CaseIterable {
    case lyricOnly = "Lyric Only"
    case songLyric = "Song + Lyric"
    case expanded = "Expanded"
}

enum LyricsColorPreset: String, CaseIterable {
    case orange = "Orange"
    case white = "White"
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
}

enum DisplayTarget: String, CaseIterable {
    case auto = "Auto Detect (Recommended)"
    case builtIn = "Built-in Display"
    case external = "External Display"
}

enum DisplayWidth: String, CaseIterable {
    case auto = "Auto"
    case compact = "Compact"
    case normal = "Normal"
    case wide = "Wide"
    case custom = "Custom"
}

enum ScreenSelection {
    static func index(target: DisplayTarget, builtIn: [Bool], containsPointer: [Bool]) -> Int? {
        guard !builtIn.isEmpty, builtIn.count == containsPointer.count else { return nil }
        switch target {
        case .builtIn:
            return builtIn.firstIndex(of: true) ?? 0
        case .external:
            return builtIn.firstIndex(of: false) ?? builtIn.firstIndex(of: true) ?? 0
        case .auto:
            return containsPointer.firstIndex(of: true) ?? builtIn.firstIndex(of: true) ?? 0
        }
    }
}

enum WidthGeometry {
    static func statusBarWidth(mode: DisplayWidth, availableWidth: CGFloat, customWidth: CGFloat) -> CGFloat {
        let fraction: CGFloat
        switch mode {
        case .compact: fraction = 0.48
        case .normal: fraction = 0.72
        case .auto, .wide: fraction = 1
        case .custom: return min(availableWidth, customWidth)
        }
        return floor(availableWidth * fraction)
    }

    static func notchWidth(
        mode: DisplayWidth,
        availableWidth: CGFloat,
        style: NotchStyle,
        customWidth: CGFloat
    ) -> CGFloat {
        let fraction: CGFloat
        switch mode {
        case .compact: fraction = 0.28
        case .normal: fraction = 0.40
        case .wide: fraction = 0.54
        case .custom: return min(availableWidth, customWidth)
        case .auto:
            switch style {
            case .lyricOnly: fraction = 0.34
            case .songLyric: fraction = 0.40
            case .expanded: fraction = 0.46
            }
        }
        return floor(availableWidth * fraction)
    }

    static func constrainedFrame(_ frame: NSRect, width: CGFloat, alignToTrailingEdge: Bool) -> NSRect {
        let resolvedWidth = min(frame.width, max(0, width))
        let x = alignToTrailingEdge ? frame.maxX - resolvedWidth : frame.minX
        return NSRect(x: x, y: frame.minY, width: resolvedWidth, height: frame.height)
    }
}

enum OverlayLaneGeometry {
    static func centeredTextY(laneHeight: CGFloat, lineHeight: CGFloat) -> CGFloat {
        floor((laneHeight - lineHeight) / 2)
    }

    static func frames(
        screenFrame: NSRect,
        auxiliaryTopLeftArea: NSRect?,
        auxiliaryTopRightArea: NSRect?,
        statusItemX: CGFloat?,
        foregroundMenuMaxX: CGFloat?,
        menuBarHeight: CGFloat
    ) -> (left: NSRect, right: NSRect) {
        let menuBar = NSRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - menuBarHeight,
            width: screenFrame.width,
            height: menuBarHeight
        )
        let leftArea = auxiliaryTopLeftArea
            ?? NSRect(x: menuBar.minX, y: menuBar.minY, width: menuBar.width / 2, height: menuBarHeight)
        let rightArea = auxiliaryTopRightArea
            ?? NSRect(x: menuBar.midX, y: menuBar.minY, width: menuBar.width / 2, height: menuBarHeight)
        let inset: CGFloat = 8

        let baseMenuBoundary = screenFrame.minX + min(520, screenFrame.width * 0.36)
        let conservativeMenuBoundary = auxiliaryTopLeftArea == nil
            ? baseMenuBoundary
            : max(baseMenuBoundary, leftArea.minX + leftArea.width * 0.82)
        let visibleMenuMaxX = foregroundMenuMaxX.flatMap {
            screenFrame.minX ... screenFrame.maxX ~= $0 ? $0 : nil
        }
        let menuBoundary = max(conservativeMenuBoundary, visibleMenuMaxX ?? conservativeMenuBoundary)
        let reservedStatusBoundary = max(rightArea.minX, rightArea.maxX - 360)
        let visibleStatusItemX = statusItemX.flatMap {
            $0 >= rightArea.minX && $0 <= rightArea.maxX ? $0 : nil
        }
        let statusBoundary = min(reservedStatusBoundary, visibleStatusItemX ?? reservedStatusBoundary)
        let leftMinX = min(leftArea.maxX, max(leftArea.minX, menuBoundary + inset))
        let rightMinX = min(rightArea.maxX, rightArea.minX + inset)
        let rightMaxX = max(rightMinX, statusBoundary - inset)

        return (
            NSRect(x: leftMinX, y: leftArea.minY, width: leftArea.maxX - leftMinX, height: leftArea.height),
            NSRect(x: rightMinX, y: rightArea.minY, width: rightMaxX - rightMinX, height: rightArea.height)
        )
    }
}

enum NotchGeometry {
    static func frame(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        style: NotchStyle,
        fontSize: CGFloat,
        width: CGFloat
    ) -> NSRect {
        let lineHeight = ceil(fontSize * 1.3)
        let height: CGFloat
        switch style {
        case .lyricOnly:
            height = lineHeight + 14
        case .songLyric:
            height = lineHeight * 2 + 18
        case .expanded:
            height = lineHeight * 4 + 22
        }

        let availableWidth = max(0, visibleFrame.width - 32)
        let resolvedWidth = min(availableWidth, max(min(240, availableWidth), width))
        let x = min(max(screenFrame.midX - resolvedWidth / 2, visibleFrame.minX), visibleFrame.maxX - resolvedWidth)
        let y = max(visibleFrame.minY, visibleFrame.maxY - height - 6)
        return NSRect(x: x, y: y, width: resolvedWidth, height: height)
    }
}

@MainActor
final class OverlayLyricsWindow: NSObject {
    @MainActor
    private final class GradientLyricView: NSView {
        var text = "" {
            didSet {
                if !oldValue.isEmpty, oldValue != text {
                    let transition = CATransition()
                    transition.duration = 0.12
                    transition.type = .fade
                    transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    layer?.add(transition, forKey: "lyricFade")
                }
                needsDisplay = true
            }
        }
        var progress: CGFloat = 0 {
            didSet { needsDisplay = true }
        }

        var font = NSFont.menuBarFont(ofSize: 0) {
            didSet { needsDisplay = true }
        }
        var baseColor = NSColor.labelColor {
            didSet { needsDisplay = true }
        }
        var gradientColors = BrandStyle.gradientColors {
            didSet { needsDisplay = true }
        }
        override func draw(_ dirtyRect: NSRect) {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: baseColor]
            (text as NSString).draw(in: bounds, withAttributes: attributes)

            guard progress > 0 else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width * min(progress, 1), height: bounds.height)).addClip()
            (text as NSString).draw(in: bounds, withAttributes: [
                .font: font,
                .foregroundColor: gradientColors[min(1, gradientColors.count - 1)]
            ])
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    @MainActor
    private final class Lane {
        let label = GradientLyricView()
        let window: NSWindow

        init(level: NSWindow.Level) {
            let contentView = NSView()
            contentView.wantsLayer = true
            contentView.layer?.masksToBounds = true

            window = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = level
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.contentView = contentView

            contentView.addSubview(label)
            label.wantsLayer = true
        }

        func show(
            frame: NSRect,
            text: String,
            progress: CGFloat,
            font: NSFont,
            colors: [NSColor],
            opacity: CGFloat,
            textX: CGFloat,
            textWidth: CGFloat,
            baseAlpha: CGFloat = 0.72
        ) {
            guard frame.width > 0 else {
                hide()
                return
            }

            if window.frame != frame {
                window.setFrame(frame, display: true)
            }
            if label.text != text {
                label.text = text
            }
            if label.progress != progress {
                label.progress = progress
            }
            if label.font != font {
                label.font = font
            }
            let baseColor = colors[0].withAlphaComponent(baseAlpha)
            if label.baseColor != baseColor {
                label.baseColor = baseColor
            }
            if label.gradientColors != colors {
                label.gradientColors = colors
            }
            if window.alphaValue != opacity {
                window.alphaValue = opacity
            }
            let lineHeight = ceil(font.ascender - font.descender + font.leading)
            let labelFrame = NSRect(
                x: textX,
                y: OverlayLaneGeometry.centeredTextY(laneHeight: frame.height, lineHeight: lineHeight),
                width: textWidth,
                height: lineHeight
            )
            if label.frame != labelFrame {
                label.frame = labelFrame
            }
            if !window.isVisible {
                window.orderFrontRegardless()
            }
        }

        func applyAppearance(_ appearance: NSAppearance?) {
            guard window.appearance !== appearance else { return }
            window.appearance = appearance
            label.appearance = appearance
            label.needsDisplay = true
        }

        func hide() {
            if window.isVisible {
                window.orderOut(nil)
            }
        }
    }

    @MainActor
    private final class NotchLyricsView: NSView {
        var onHoverChanged: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?
        var lyric = "" {
            didSet {
                if !oldValue.isEmpty, oldValue != lyric {
                    let transition = CATransition()
                    transition.duration = 0.12
                    transition.type = .fade
                    layer?.add(transition, forKey: "notchLyricFade")
                }
            }
        }
        var song = ""
        var artist = ""
        var progress: CGFloat = 0
        var font = NSFont.systemFont(ofSize: 13, weight: .medium)
        var style = NotchStyle.lyricOnly
        var colors = BrandStyle.gradientColors
        var lyricViewport = NSRect.zero
        var lyricTextRect = NSRect.zero
        var lyricWraps = false

        override func updateTrackingAreas() {
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
            super.updateTrackingAreas()
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChanged?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChanged?(false)
        }

        override func draw(_ dirtyRect: NSRect) {
            let cornerRadius = style == .lyricOnly ? bounds.height / 2 : min(16, bounds.height * 0.28)
            NSColor.white.withAlphaComponent(0.12).setStroke()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius).stroke()

            let lineHeight = ceil(font.pointSize * 1.3)

            switch style {
            case .lyricOnly:
                break
            case .songLyric:
                drawMetadata(
                    "\(song) · \(artist)",
                    in: NSRect(x: 16, y: bounds.height - lineHeight - 5, width: bounds.width - 32, height: lineHeight),
                    font: .systemFont(ofSize: max(10, font.pointSize - 2), weight: .medium),
                    alignment: .center
                )
            case .expanded:
                let iconSize = min(26, lineHeight * 1.25)
                BrandStyle.noteImage().draw(in: NSRect(x: 16, y: bounds.height - lineHeight * 2 - 5, width: iconSize, height: iconSize))
                let metadataX = 16 + iconSize + 10
                drawMetadata(song, in: NSRect(x: metadataX, y: bounds.height - lineHeight - 5, width: bounds.width - metadataX - 16, height: lineHeight), font: .systemFont(ofSize: max(11, font.pointSize), weight: .semibold), alignment: .left)
                drawMetadata(artist, in: NSRect(x: metadataX, y: bounds.height - lineHeight * 2 - 3, width: bounds.width - metadataX - 16, height: lineHeight), font: .systemFont(ofSize: max(10, font.pointSize - 2)), alignment: .left)
            }

            drawLyric()
        }

        private func drawMetadata(_ text: String, in rect: NSRect, font: NSFont, alignment: NSTextAlignment) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byTruncatingTail
            (text as NSString).draw(in: rect, withAttributes: [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(0.88),
                .paragraphStyle: paragraph
            ])
        }

        private func drawLyric() {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: lyricViewport).addClip()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(0.62),
                .shadow: textShadow()
            ]
            drawLyricText(attributes: attributes)

            if progress > 0 {
                NSBezierPath(rect: NSRect(
                    x: lyricTextRect.minX,
                    y: lyricTextRect.minY,
                    width: lyricTextRect.width * min(progress, 1),
                    height: lyricTextRect.height
                )).addClip()
                drawLyricText(attributes: [
                    .font: font,
                    .foregroundColor: colors[min(1, colors.count - 1)],
                    .shadow: textShadow()
                ])
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        private func drawLyricText(attributes: [NSAttributedString.Key: Any]) {
            if lyricWraps {
                (lyric as NSString).draw(
                    with: lyricTextRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
                    attributes: attributes
                )
            } else {
                (lyric as NSString).draw(in: lyricTextRect, withAttributes: attributes)
            }
        }

        private func textShadow() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            return shadow
        }
    }

    @MainActor
    private final class NotchLane {
        let view = NotchLyricsView()
        let window: NSWindow
        private let materialView = NSVisualEffectView()
        private let tintView = NSView()
        private var isHovered = false
        private var configuredOpacity: CGFloat = 1

        init() {
            window = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.appearance = NSAppearance(named: .darkAqua)
            materialView.material = .hudWindow
            materialView.blendingMode = .behindWindow
            materialView.state = .active
            materialView.wantsLayer = true
            tintView.wantsLayer = true
            materialView.addSubview(tintView)
            materialView.addSubview(view)
            window.contentView = materialView
            view.wantsLayer = true
            view.onHoverChanged = { [weak self] hovering in
                self?.setHovered(hovering)
            }
        }

        func show(
            frame: NSRect,
            lyric: String,
            song: String,
            artist: String,
            progress: CGFloat,
            style requestedStyle: NotchStyle,
            fontSize: CGFloat,
            colors: [NSColor],
            opacity: CGFloat,
            scroll: ScrollState,
            animationSpeed: CGFloat,
            hideOnHover: Bool
        ) -> Bool {
            let style: NotchStyle = song.isEmpty ? .lyricOnly : requestedStyle
            let displayLyric = lyric
            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            let horizontalInset: CGFloat = 16
            let lyricY: CGFloat = style == .lyricOnly ? floor((frame.height - ceil(fontSize * 1.3)) / 2) : 6
            let lyricWraps = style == .expanded
            let lineHeight = ceil(fontSize * 1.3)
            let viewport = NSRect(
                x: horizontalInset,
                y: lyricY,
                width: max(0, frame.width - horizontalInset * 2),
                height: lyricWraps ? lineHeight * 2 : lineHeight
            )
            let measuredWidth = ceil((displayLyric as NSString).size(withAttributes: [.font: font]).width)
            let textWidth = lyricWraps ? viewport.width : measuredWidth
            let overflows = !lyricWraps && textWidth > viewport.width
            let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: viewport.width, speedMultiplier: animationSpeed) : 0
            let textX = lyricWraps ? viewport.minX : overflows ? viewport.minX - offset : viewport.midX - textWidth / 2

            if window.frame != frame {
                window.setFrame(frame, display: true)
            }
            materialView.frame = NSRect(origin: .zero, size: frame.size)
            materialView.layer?.cornerRadius = style == .lyricOnly ? frame.height / 2 : min(16, frame.height * 0.28)
            materialView.layer?.masksToBounds = true
            tintView.frame = materialView.bounds
            tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(style == .lyricOnly ? 0.76 : 0.82).cgColor
            view.frame = NSRect(origin: .zero, size: frame.size)
            view.lyric = displayLyric
            view.song = song
            view.artist = artist
            view.progress = progress
            view.font = font
            view.style = style
            view.colors = colors
            view.lyricViewport = viewport
            view.lyricTextRect = NSRect(x: textX, y: lyricY, width: textWidth, height: viewport.height)
            view.lyricWraps = lyricWraps
            view.needsDisplay = true
            window.ignoresMouseEvents = !hideOnHover
            if !hideOnHover, isHovered {
                isHovered = false
            }
            if configuredOpacity != opacity {
                configuredOpacity = opacity
            }
            let targetOpacity = isHovered ? 0.06 : configuredOpacity
            if !window.isVisible {
                window.alphaValue = targetOpacity
                window.orderFrontRegardless()
            } else if abs(window.alphaValue - targetOpacity) > 0.01 {
                window.animator().alphaValue = targetOpacity
            }
            return overflows
        }

        func applyAppearance(_ appearance: NSAppearance?) {
            window.appearance = appearance
            view.appearance = appearance
            view.needsDisplay = true
        }

        func hide() {
            if window.isVisible {
                window.orderOut(nil)
            }
        }

        private func setHovered(_ hovering: Bool) {
            guard !window.ignoresMouseEvents, isHovered != hovering else { return }
            isHovered = hovering
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                window.animator().alphaValue = hovering ? 0.06 : configuredOpacity
            }
        }
    }

    private let leftLane = Lane(level: .mainMenu)
    private let rightLane = Lane(level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1))
    private let notchLane = NotchLane()

    func hide() {
        leftLane.hide()
        rightLane.hide()
        notchLane.hide()
    }

    func show(
        text: String,
        progress: CGFloat,
        mode: DisplayMode,
        position: LyricsPosition,
        notchStyle: NotchStyle,
        song: String,
        artist: String,
        statusItem: NSStatusItem,
        scroll: ScrollState,
        fontSize: CGFloat,
        animationSpeed: CGFloat,
        colorPreset: LyricsColorPreset,
        opacity: CGFloat,
        displayTarget: DisplayTarget,
        displayWidth: DisplayWidth,
        customWidth: CGFloat,
        hideOnHover: Bool
    ) -> Bool {
        guard let screen = selectedScreen(target: displayTarget, statusItem: statusItem) else { return false }
        let colors = BrandStyle.gradientColors(for: colorPreset)

        if mode == .notch {
            leftLane.hide()
            rightLane.hide()
            notchLane.applyAppearance(statusItem.button?.effectiveAppearance)
            let effectiveStyle: NotchStyle = song.isEmpty ? .lyricOnly : notchStyle
            let availableWidth = max(0, screen.visibleFrame.width - 32)
            let width = WidthGeometry.notchWidth(
                mode: displayWidth,
                availableWidth: availableWidth,
                style: effectiveStyle,
                customWidth: customWidth
            )
            let frame = NotchGeometry.frame(
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                style: effectiveStyle,
                fontSize: fontSize,
                width: width
            )
            return notchLane.show(
                frame: frame,
                lyric: text,
                song: song,
                artist: artist,
                progress: progress,
                style: effectiveStyle,
                fontSize: fontSize,
                colors: colors,
                opacity: opacity,
                scroll: scroll,
                animationSpeed: animationSpeed,
                hideOnHover: hideOnHover
            )
        }

        notchLane.hide()
        leftLane.applyAppearance(statusItem.button?.effectiveAppearance)
        rightLane.applyAppearance(statusItem.button?.effectiveAppearance)
        let availableFrames = OverlayLaneGeometry.frames(
            screenFrame: screen.frame,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            statusItemX: statusItem.button?.window?.screen == screen ? statusItemScreenMinX(statusItem) : nil,
            foregroundMenuMaxX: position == .left ? MenuBarSafety.foregroundMenuMaxX() : nil,
            menuBarHeight: NSStatusBar.system.thickness
        )
        let frames = (
            left: WidthGeometry.constrainedFrame(
                availableFrames.left,
                width: WidthGeometry.statusBarWidth(mode: displayWidth, availableWidth: availableFrames.left.width, customWidth: customWidth),
                alignToTrailingEdge: true
            ),
            right: WidthGeometry.constrainedFrame(
                availableFrames.right,
                width: WidthGeometry.statusBarWidth(mode: displayWidth, availableWidth: availableFrames.right.width, customWidth: customWidth),
                alignToTrailingEdge: false
            )
        )
        let statusText = "♪ \(text)"
        let font = NSFont.menuBarFont(ofSize: fontSize)
        let textWidth = ceil((statusText as NSString).size(withAttributes: [.font: font]).width)

        switch position {
        case .left:
            rightLane.hide()
            return showSingle(text: statusText, progress: progress, font: font, colors: colors, opacity: opacity, textWidth: textWidth, frame: frames.left, lane: leftLane, scroll: scroll, animationSpeed: animationSpeed)
        case .right:
            leftLane.hide()
            return showSingle(text: statusText, progress: progress, font: font, colors: colors, opacity: opacity, textWidth: textWidth, frame: frames.right, lane: rightLane, scroll: scroll, animationSpeed: animationSpeed)
        }
    }

    private func statusItemScreenMinX(_ statusItem: NSStatusItem) -> CGFloat? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow).minX
    }

    private func selectedScreen(target: DisplayTarget, statusItem: NSStatusItem) -> NSScreen? {
        let screens = NSScreen.screens
        let pointer = NSEvent.mouseLocation
        let index = ScreenSelection.index(
            target: target,
            builtIn: screens.map(isBuiltIn),
            containsPointer: screens.map { $0.frame.contains(pointer) }
        )
        return index.flatMap { screens.indices.contains($0) ? screens[$0] : nil }
            ?? statusItem.button?.window?.screen
            ?? NSScreen.main
    }

    private func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }

    private func showSingle(
        text: String,
        progress: CGFloat,
        font: NSFont,
        colors: [NSColor],
        opacity: CGFloat,
        textWidth: CGFloat,
        frame: NSRect,
        lane: Lane,
        scroll: ScrollState,
        animationSpeed: CGFloat
    ) -> Bool {
        let overflows = frame.width > 0 && textWidth > frame.width
        let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: frame.width, speedMultiplier: animationSpeed) : 0
        let x = overflows ? -offset : (frame.width - textWidth) / 2
        lane.show(frame: frame, text: text, progress: progress, font: font, colors: colors, opacity: opacity, textX: x, textWidth: textWidth)
        return overflows
    }

}
