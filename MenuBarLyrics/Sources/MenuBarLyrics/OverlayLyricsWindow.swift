import AppKit

@MainActor
final class OverlayLyricsWindow {
    private let label = NSTextField(labelWithString: "")
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = label
        return window
    }()

    func show(width: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let menuHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        let maxXBeforeStatusIcons = screen.frame.maxX - 600
        let x = min(screen.frame.minX + 520, maxXBeforeStatusIcons - width)
        let frame = NSRect(
            x: max(screen.frame.minX + 260, x),
            y: screen.frame.maxY - menuHeight,
            width: width,
            height: menuHeight
        )

        label.frame = NSRect(origin: .zero, size: frame.size)
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = .zero
        label.shadow = shadow
        label.alignment = .left
        label.lineBreakMode = .byClipping
        label.drawsBackground = false

        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
    }

    func setText(_ text: String) {
        label.stringValue = text
    }
}
