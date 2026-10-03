import AppKit

@MainActor
enum AppearanceSurfaceColors {
    static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static let card = adaptive(light: .white.withAlphaComponent(0.73),
                               dark: NSColor(calibratedWhite: 0.16, alpha: 0.94))
    static let sidebar = adaptive(light: .white.withAlphaComponent(0.46),
                                  dark: NSColor(calibratedWhite: 0.12, alpha: 0.88))
    static let border = adaptive(light: .white.withAlphaComponent(0.8),
                                 dark: .white.withAlphaComponent(0.12))
    static let backdropStart = adaptive(light: NSColor(calibratedRed: 1, green: 0.91, blue: 0.88, alpha: 1),
                                        dark: NSColor(calibratedWhite: 0.10, alpha: 1))
    static let backdropEnd = adaptive(light: NSColor(calibratedRed: 0.79, green: 0.87, blue: 1, alpha: 1),
                                      dark: NSColor(calibratedWhite: 0.18, alpha: 1))
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
