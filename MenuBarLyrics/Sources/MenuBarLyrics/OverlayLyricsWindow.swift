import AppKit

enum LyricsPosition: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case both = "Both"

    var menuTitle: String {
        switch self {
        case .left: return "歌词显示在左侧"
        case .right: return "歌词显示在右侧"
        case .both: return "歌词显示在双侧"
        }
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

        let conservativeMenuBoundary = max(screenFrame.minX + 520, leftArea.minX + leftArea.width * 0.82)
        let menuBoundary = max(conservativeMenuBoundary, foregroundMenuMaxX ?? conservativeMenuBoundary)
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

@MainActor
final class OverlayLyricsWindow: NSObject {
    @MainActor
    private final class GradientLyricView: NSView {
        var text = "" {
            didSet { needsDisplay = true }
        }
        var progress: CGFloat = 0 {
            didSet { needsDisplay = true }
        }

        let font = NSFont.menuBarFont(ofSize: 0)

        override func draw(_ dirtyRect: NSRect) {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            (text as NSString).draw(in: bounds, withAttributes: attributes)

            guard progress > 0, let gradient = NSGradient(colors: BrandStyle.gradientColors) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width * min(progress, 1), height: bounds.height)).addClip()
            (text as NSString).draw(in: bounds, withAttributes: attributes)
            NSGraphicsContext.current?.compositingOperation = .sourceIn
            gradient.draw(in: bounds, angle: 0)
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
        }

        func show(frame: NSRect, text: String, progress: CGFloat, textX: CGFloat, textWidth: CGFloat) {
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
            let font = label.font
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

    private let leftLane = Lane(level: .mainMenu)
    private let rightLane = Lane(level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1))
    private let font = NSFont.menuBarFont(ofSize: 0)

    func show(
        text: String,
        progress: CGFloat,
        position: LyricsPosition,
        statusItem: NSStatusItem,
        scroll: ScrollState
    ) -> Bool {
        guard let screen = statusItem.button?.window?.screen ?? NSScreen.main else { return false }
        leftLane.applyAppearance(statusItem.button?.effectiveAppearance)
        rightLane.applyAppearance(statusItem.button?.effectiveAppearance)
        let frames = OverlayLaneGeometry.frames(
            screenFrame: screen.frame,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            statusItemX: statusItemScreenMinX(statusItem),
            foregroundMenuMaxX: position == .right ? nil : MenuBarSafety.foregroundMenuMaxX(),
            menuBarHeight: NSStatusBar.system.thickness
        )
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)

        switch position {
        case .left:
            rightLane.hide()
            return showSingle(text: text, progress: progress, textWidth: textWidth, frame: frames.left, lane: leftLane, scroll: scroll)
        case .right:
            leftLane.hide()
            return showSingle(text: text, progress: progress, textWidth: textWidth, frame: frames.right, lane: rightLane, scroll: scroll)
        case .both:
            return showBoth(text: text, progress: progress, textWidth: textWidth, frames: frames, scroll: scroll)
        }
    }

    private func statusItemScreenMinX(_ statusItem: NSStatusItem) -> CGFloat? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow).minX
    }

    private func showSingle(
        text: String,
        progress: CGFloat,
        textWidth: CGFloat,
        frame: NSRect,
        lane: Lane,
        scroll: ScrollState
    ) -> Bool {
        let overflows = frame.width > 0 && textWidth > frame.width
        let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: frame.width) : 0
        let x = overflows ? -offset : (frame.width - textWidth) / 2
        lane.show(frame: frame, text: text, progress: progress, textX: x, textWidth: textWidth)
        return overflows
    }

    private func showBoth(
        text: String,
        progress: CGFloat,
        textWidth: CGFloat,
        frames: (left: NSRect, right: NSRect),
        scroll: ScrollState
    ) -> Bool {
        if textWidth <= min(frames.left.width, frames.right.width) {
            leftLane.show(
                frame: frames.left,
                text: text,
                progress: progress,
                textX: textWidth <= frames.left.width ? (frames.left.width - textWidth) / 2 : 0,
                textWidth: textWidth
            )
            rightLane.show(
                frame: frames.right,
                text: text,
                progress: progress,
                textX: textWidth <= frames.right.width ? (frames.right.width - textWidth) / 2 : 0,
                textWidth: textWidth
            )
            return false
        }

        let viewportWidth = frames.left.width + frames.right.width
        let overflows = viewportWidth > 0 && textWidth > viewportWidth
        let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: viewportWidth) : 0
        leftLane.show(frame: frames.left, text: text, progress: progress, textX: -offset, textWidth: textWidth)
        rightLane.show(
            frame: frames.right,
            text: text,
            progress: progress,
            textX: -frames.left.width - offset,
            textWidth: textWidth
        )
        return overflows
    }
}
