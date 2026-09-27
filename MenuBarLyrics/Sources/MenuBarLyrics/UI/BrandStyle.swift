import AppKit

enum BrandStyle {
    static let gradientColors = [
        NSColor(calibratedRed: 232 / 255, green: 121 / 255, blue: 36 / 255, alpha: 1),
        NSColor(calibratedRed: 200 / 255, green: 90 / 255, blue: 18 / 255, alpha: 1),
        NSColor(calibratedRed: 150 / 255, green: 58 / 255, blue: 8 / 255, alpha: 1)
    ]

    static func gradientColors(for preset: LyricsColorPreset, customColor: NSColor = gradientColors[0], customEndColor: NSColor = .systemTeal) -> [NSColor] {
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
        case .mintGradient:
            return [NSColor(calibratedRed: 0.89, green: 1, blue: 0.98, alpha: 1),
                    NSColor(calibratedRed: 0.56, green: 0.98, blue: 0.96, alpha: 1),
                    NSColor(calibratedRed: 0.23, green: 0.77, blue: 0.88, alpha: 1)]
        case .sunsetGradient:
            return [NSColor(calibratedRed: 1, green: 0.88, blue: 0.68, alpha: 1),
                    NSColor(calibratedRed: 1, green: 0.60, blue: 0.59, alpha: 1),
                    NSColor(calibratedRed: 0.83, green: 0.55, blue: 0.95, alpha: 1)]
        case .custom:
            return [customColor, customColor, customColor]
        case .customGradient:
            return [customColor, customEndColor]
        case .red: return [.systemRed]
        case .pink: return [.systemPink]
        case .cyan: return [.systemTeal]
        case .yellow: return [.systemYellow]
        case .silver: return [NSColor(white: 0.85, alpha: 1)]
        case .coral: return [NSColor(calibratedRed: 1, green: 0.46, blue: 0.36, alpha: 1)]
        case .lavender: return [NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.96, alpha: 1)]
        case .oceanGradient: return [.systemTeal, .systemBlue]
        case .auroraGradient: return [.systemGreen, .systemTeal, .systemBlue]
        case .roseGradient: return [.systemPink, .systemPurple]
        case .violetGradient: return [.systemPurple, .systemBlue]
        case .peachGradient: return [.systemOrange, .systemPink]
        case .skyGradient: return [.white, .systemCyan, .systemBlue]
        case .limeGradient: return [.systemYellow, .systemGreen]
        case .goldGradient: return [.white, .systemYellow, .systemOrange]
        }
    }

    static func gradientLyric(_ text: String, colors: [NSColor], attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        let length = (text as NSString).length
        guard colors.count > 1, length > 0 else { return result }
        (text as NSString).enumerateSubstrings(in: NSRange(location: 0, length: length), options: .byComposedCharacterSequences) { _, range, _, _ in
            let position = CGFloat(range.location) / CGFloat(max(1, length - 1)) * CGFloat(colors.count - 1)
            let index = min(colors.count - 2, Int(position))
            let fraction = position - CGFloat(index)
            let color = fraction == 0 ? colors[index] : fraction == 1 ? colors[index + 1]
                : (colors[index].blended(withFraction: fraction, of: colors[index + 1]) ?? colors[index])
            result.addAttribute(.foregroundColor, value: color, range: range)
        }
        return result
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
