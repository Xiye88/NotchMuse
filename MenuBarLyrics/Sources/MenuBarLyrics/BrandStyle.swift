import AppKit

enum BrandStyle {
    static let gradientColors = [
        NSColor(calibratedRed: 232 / 255, green: 121 / 255, blue: 36 / 255, alpha: 1),
        NSColor(calibratedRed: 200 / 255, green: 90 / 255, blue: 18 / 255, alpha: 1),
        NSColor(calibratedRed: 150 / 255, green: 58 / 255, blue: 8 / 255, alpha: 1)
    ]

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
