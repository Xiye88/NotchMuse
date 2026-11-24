import AppKit

@MainActor
enum AppearanceSurfaceColors {
    static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    // Hi-Fi Studio Dark (#141416) & Braun Warm Alabaster Light (#F5F4F0)
    static let windowBackground = adaptive(
        light: NSColor(calibratedRed: 0.961, green: 0.957, blue: 0.941, alpha: 1),
        dark: NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.086, alpha: 1)
    )
    static let sidebarTop = adaptive(
        light: NSColor(calibratedRed: 0.925, green: 0.918, blue: 0.894, alpha: 1),
        dark: NSColor(calibratedRed: 0.106, green: 0.106, blue: 0.122, alpha: 1)
    )
    static let sidebarBottom = adaptive(
        light: NSColor(calibratedRed: 0.902, green: 0.890, blue: 0.863, alpha: 1),
        dark: NSColor(calibratedRed: 0.075, green: 0.075, blue: 0.086, alpha: 1)
    )
    static let card = adaptive(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.78),
        dark: NSColor(calibratedRed: 0.114, green: 0.114, blue: 0.125, alpha: 0.96)
    )
    static let deck = adaptive(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.65),
        dark: NSColor(calibratedWhite: 0.0, alpha: 0.42)
    )
    static let sidebar = sidebarTop
    static let border = adaptive(
        light: NSColor(calibratedRed: 0.094, green: 0.094, blue: 0.106, alpha: 0.09),
        dark: NSColor.white.withAlphaComponent(0.09)
    )
    static let accent = adaptive(
        light: NSColor(calibratedRed: 0.878, green: 0.427, blue: 0.106, alpha: 1),
        dark: NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1)
    )
    static let accentSoft = adaptive(
        light: NSColor(calibratedRed: 0.878, green: 0.427, blue: 0.106, alpha: 0.12),
        dark: NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 0.14)
    )
    static let accentBorder = adaptive(
        light: NSColor(calibratedRed: 0.878, green: 0.427, blue: 0.106, alpha: 0.36),
        dark: NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 0.38)
    )
    static let ledOff = adaptive(
        light: NSColor(calibratedRed: 0.094, green: 0.094, blue: 0.106, alpha: 0.14),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let backdropStart = windowBackground
    static let backdropEnd = windowBackground
}

class AppearanceSurfaceView: NSView {
    var surfaceColor: NSColor = .clear { didSet { needsDisplay = true } }
    var surfaceBorderColor: NSColor = AppearanceSurfaceColors.border { didSet { needsDisplay = true } }
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        onAppearanceChange?()
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = surfaceColor.cgColor
            layer?.borderColor = surfaceBorderColor.cgColor
        }
    }

    override var wantsUpdateLayer: Bool { true }
}
