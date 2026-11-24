import AppKit

@MainActor
enum AppearanceSurfaceColors {
    static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static let card = adaptive(light: NSColor(calibratedWhite: 1.0, alpha: 0.92),
                               dark: NSColor(calibratedWhite: 0.16, alpha: 0.92))
    static let sidebar = adaptive(light: NSColor(calibratedWhite: 0.96, alpha: 1),
                                  dark: NSColor(calibratedWhite: 0.12, alpha: 1))
    static let border = adaptive(light: NSColor.black.withAlphaComponent(0.08),
                                 dark: NSColor.white.withAlphaComponent(0.10))
    static let backdropStart = adaptive(light: NSColor.windowBackgroundColor,
                                        dark: NSColor.windowBackgroundColor)
    static let backdropEnd = adaptive(light: NSColor.windowBackgroundColor,
                                      dark: NSColor.windowBackgroundColor)
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
