import AppKit

enum LyricsPosition: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
}

enum OverlayLaneGeometry {
    static func frames(
        screenFrame: NSRect,
        auxiliaryTopLeftArea: NSRect?,
        auxiliaryTopRightArea: NSRect?,
        statusItemX: CGFloat?,
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

        // AppKit does not expose the foreground app's command widths without Accessibility.
        let menuBoundary = max(screenFrame.minX + 520, leftArea.minX + leftArea.width * 0.82)
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
final class OverlayLyricsWindow {
    @MainActor
    private final class Lane {
        let label = NSTextField(labelWithString: "")
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

            label.font = .menuBarFont(ofSize: 0)
            label.textColor = .labelColor
            label.lineBreakMode = .byClipping
            label.drawsBackground = false
            label.isBezeled = false
            label.isEditable = false
            label.isSelectable = false
            contentView.addSubview(label)
        }

        func show(frame: NSRect, text: String, textX: CGFloat, textWidth: CGFloat) {
            guard frame.width > 0 else {
                hide()
                return
            }

            if window.frame != frame {
                window.setFrame(frame, display: true)
            }
            if label.stringValue != text {
                label.stringValue = text
            }
            let labelFrame = NSRect(x: textX, y: 0, width: textWidth, height: frame.height)
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
            label.textColor = .labelColor
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
            menuBarHeight: NSStatusBar.system.thickness
        )
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)

        switch position {
        case .left:
            rightLane.hide()
            return showSingle(text: text, textWidth: textWidth, frame: frames.left, lane: leftLane, scroll: scroll)
        case .right:
            leftLane.hide()
            return showSingle(text: text, textWidth: textWidth, frame: frames.right, lane: rightLane, scroll: scroll)
        case .both:
            return showBoth(text: text, textWidth: textWidth, frames: frames, scroll: scroll)
        }
    }

    private func statusItemScreenMinX(_ statusItem: NSStatusItem) -> CGFloat? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow).minX
    }

    private func showSingle(
        text: String,
        textWidth: CGFloat,
        frame: NSRect,
        lane: Lane,
        scroll: ScrollState
    ) -> Bool {
        let overflows = frame.width > 0 && textWidth > frame.width
        let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: frame.width) : 0
        let x = overflows ? -offset : (frame.width - textWidth) / 2
        lane.show(frame: frame, text: text, textX: x, textWidth: textWidth)
        return overflows
    }

    private func showBoth(
        text: String,
        textWidth: CGFloat,
        frames: (left: NSRect, right: NSRect),
        scroll: ScrollState
    ) -> Bool {
        let widerIsLeft = frames.left.width >= frames.right.width
        let widerFrame = widerIsLeft ? frames.left : frames.right

        if textWidth <= widerFrame.width {
            let x = (widerFrame.width - textWidth) / 2
            leftLane.show(
                frame: frames.left,
                text: widerIsLeft ? text : "",
                textX: widerIsLeft ? x : 0,
                textWidth: widerIsLeft ? textWidth : 0
            )
            rightLane.show(
                frame: frames.right,
                text: widerIsLeft ? "" : text,
                textX: widerIsLeft ? 0 : x,
                textWidth: widerIsLeft ? 0 : textWidth
            )
            return false
        }

        let viewportWidth = frames.left.width + frames.right.width
        let overflows = viewportWidth > 0 && textWidth > viewportWidth
        let offset = overflows ? scroll.offset(contentWidth: textWidth, viewportWidth: viewportWidth) : 0
        leftLane.show(frame: frames.left, text: text, textX: -offset, textWidth: textWidth)
        rightLane.show(
            frame: frames.right,
            text: text,
            textX: -frames.left.width - offset,
            textWidth: textWidth
        )
        return overflows
    }
}
