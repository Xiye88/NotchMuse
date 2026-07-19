import AppKit

enum BrandStyle {
    static let gradientColors = [
        NSColor(calibratedRed: 232 / 255, green: 121 / 255, blue: 36 / 255, alpha: 1),
        NSColor(calibratedRed: 200 / 255, green: 90 / 255, blue: 18 / 255, alpha: 1),
        NSColor(calibratedRed: 150 / 255, green: 58 / 255, blue: 8 / 255, alpha: 1)
    ]

    static func gradientColors(for preset: LyricsColorPreset) -> [NSColor] {
        switch preset {
        case .orange:
            return gradientColors
        case .white:
            return [.white, NSColor(white: 0.9, alpha: 1), NSColor(white: 0.75, alpha: 1)]
        case .blue:
            return [
                NSColor(calibratedRed: 90 / 255, green: 169 / 255, blue: 1, alpha: 1),
                NSColor(calibratedRed: 52 / 255, green: 120 / 255, blue: 246 / 255, alpha: 1),
                NSColor(calibratedRed: 29 / 255, green: 78 / 255, blue: 216 / 255, alpha: 1)
            ]
        case .purple:
            return [
                NSColor(calibratedRed: 191 / 255, green: 90 / 255, blue: 242 / 255, alpha: 1),
                NSColor(calibratedRed: 155 / 255, green: 81 / 255, blue: 224 / 255, alpha: 1),
                NSColor(calibratedRed: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1)
            ]
        case .green:
            return [
                NSColor(calibratedRed: 90 / 255, green: 207 / 255, blue: 134 / 255, alpha: 1),
                NSColor(calibratedRed: 52 / 255, green: 199 / 255, blue: 89 / 255, alpha: 1),
                NSColor(calibratedRed: 23 / 255, green: 138 / 255, blue: 67 / 255, alpha: 1)
            ]
        }
    }

    static func noteImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        guard let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchMuse"),
              let gradient = NSGradient(colors: gradientColors) else {
            return image
        }

        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        symbol.draw(in: rect)
        NSGraphicsContext.current?.compositingOperation = .sourceIn
        gradient.draw(in: rect, angle: 90)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
