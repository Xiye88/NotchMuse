import AppKit

enum BrandStyle {
    static func noteImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        guard let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Menu Bar Lyrics"),
              let gradient = NSGradient(colors: [.systemPink, .systemOrange, .systemYellow]) else {
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
