import AppKit
import LyricsCore
import UniformTypeIdentifiers

enum LyricShareTemplate: String, CaseIterable, Sendable {
    case vinylDark
    case warmAlabaster
    case mistySage

    func displayName(isZh: Bool) -> String {
        switch self {
        case .vinylDark: return isZh ? "黑胶暗夜" : "Vinyl Dark"
        case .warmAlabaster: return isZh ? "暖雪花石" : "Warm Alabaster"
        case .mistySage: return isZh ? "汽水雾青" : "Misty Sage"
        }
    }
}

@MainActor
enum LyricShareCardRenderer {
    static let logicalWidth: CGFloat = 440

    static func defaultSelectedIndices(linesCount: Int, activeIndex: Int) -> [Int] {
        guard linesCount > 0 else { return [] }
        let targetCount = min(4, linesCount)
        let center = (0..<linesCount).contains(activeIndex) ? activeIndex : 0
        var start = max(0, center - 1)
        if start + targetCount > linesCount {
            start = max(0, linesCount - targetCount)
        }
        return Array(start..<(start + targetCount))
    }

    static func renderPNG(
        lines: [String],
        trackTitle: String,
        artistName: String,
        albumName: String = "",
        artworkImage: NSImage? = nil,
        template: LyricShareTemplate
    ) -> (image: NSImage, pngData: Data)? {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let displayLines = cleaned.isEmpty ? ["♪"] : Array(cleaned.prefix(6))
        let safeTitle = trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "NotchMuse" : trackTitle
        let safeArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeAlbum = albumName.trimmingCharacters(in: .whitespacesAndNewlines)

        let padX: CGFloat = 36
        let textWidth = logicalWidth - padX * 2

        let lyricParagraph = NSMutableParagraphStyle()
        lyricParagraph.lineSpacing = 7
        lyricParagraph.alignment = .left

        var lyricFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
        var measuredHeights: [CGFloat] = []
        var totalLyricsHeight: CGFloat = 0
        func measureLines(font: NSFont) -> ([CGFloat], CGFloat) {
            var heights: [CGFloat] = []
            var total: CGFloat = 0
            for line in displayLines {
                let rect = (line as NSString).boundingRect(
                    with: NSSize(width: textWidth, height: 220),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .paragraphStyle: lyricParagraph]
                )
                let h = ceil(rect.height)
                heights.append(h)
                total += h
            }
            return (heights, total)
        }
        (measuredHeights, totalLyricsHeight) = measureLines(font: lyricFont)
        if totalLyricsHeight > 420 {
            lyricFont = NSFont.systemFont(ofSize: 17, weight: .semibold)
            (measuredHeights, totalLyricsHeight) = measureLines(font: lyricFont)
        }
        let lineGap: CGFloat = 14
        if displayLines.count > 1 {
            totalLyricsHeight += CGFloat(displayLines.count - 1) * lineGap
        }

        let headerH: CGFloat = 134
        let footerH: CGFloat = 72
        let logicalHeight = min(940, max(520, headerH + totalLyricsHeight + footerH + 54))

        let scale: CGFloat = 2
        let pixelW = Int(logicalWidth * scale)
        let pixelH = Int(logicalHeight * scale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: logicalWidth, height: logicalHeight)

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext
        cg.setAllowsAntialiasing(true)
        cg.setShouldAntialias(true)
        cg.setShouldSmoothFonts(true)

        let canvas = NSRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
        drawBackground(in: canvas, template: template)
        drawOrnament(in: canvas, template: template)

        // Colors per template
        let primaryTextColor: NSColor
        let secondaryTextColor: NSColor
        let accentColor: NSColor
        let ruleColor: NSColor

        switch template {
        case .vinylDark:
            primaryTextColor = NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.93, alpha: 0.98)
            secondaryTextColor = NSColor(calibratedRed: 0.72, green: 0.71, blue: 0.70, alpha: 0.85)
            accentColor = NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1)
            ruleColor = NSColor.white.withAlphaComponent(0.11)
        case .warmAlabaster:
            primaryTextColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.96)
            secondaryTextColor = NSColor(calibratedRed: 0.42, green: 0.39, blue: 0.36, alpha: 0.9)
            accentColor = NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.14, alpha: 1)
            ruleColor = NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.14, alpha: 0.24)
        case .mistySage:
            primaryTextColor = NSColor.white.withAlphaComponent(0.97)
            secondaryTextColor = NSColor(calibratedRed: 0.82, green: 0.92, blue: 0.89, alpha: 0.82)
            accentColor = NSColor(calibratedRed: 0.62, green: 0.92, blue: 0.82, alpha: 1)
            ruleColor = NSColor.white.withAlphaComponent(0.16)
        }

        // Top editorial header: 56x56pt rounded album artwork (left) + bold track title & artist/album (right)
        let artSize: CGFloat = 56
        let artRect = NSRect(x: padX, y: logicalHeight - 38 - artSize, width: artSize, height: artSize)
        drawHeaderArtwork(artworkImage, in: artRect, accentColor: accentColor, template: template)

        let metaX = artRect.maxX + 14
        let metaW = logicalWidth - padX - metaX - 4
        let metaParagraph = NSMutableParagraphStyle()
        metaParagraph.lineBreakMode = .byTruncatingTail

        let subtitleText: String
        let showAlbum = !safeAlbum.isEmpty && safeAlbum.caseInsensitiveCompare(safeTitle) != .orderedSame
        if !safeArtist.isEmpty && showAlbum {
            subtitleText = AppPreferences.language == .simplifiedChinese
                ? "\(safeArtist) · 《\(safeAlbum)》"
                : "\(safeArtist) · \(safeAlbum)"
        } else if !safeArtist.isEmpty {
            subtitleText = safeArtist
        } else if showAlbum {
            subtitleText = AppPreferences.language == .simplifiedChinese ? "《\(safeAlbum)》" : safeAlbum
        } else {
            subtitleText = ""
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: primaryTextColor,
            .paragraphStyle: metaParagraph
        ]
        let titleY: CGFloat = subtitleText.isEmpty ? (artRect.midY - 10) : (artRect.midY + 2)
        (safeTitle as NSString).draw(
            in: NSRect(x: metaX, y: titleY, width: metaW, height: 22),
            withAttributes: titleAttrs
        )
        if !subtitleText.isEmpty {
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: secondaryTextColor,
                .paragraphStyle: metaParagraph
            ]
            (subtitleText as NSString).draw(
                in: NSRect(x: metaX, y: artRect.midY - 19, width: metaW, height: 18),
                withAttributes: subAttrs
            )
        }

        // Hairline rule below header
        let headerDividerY = artRect.minY - 18
        ruleColor.setFill()
        NSRect(x: padX, y: headerDividerY, width: textWidth, height: 1).fill()

        // Draw lyrics centered vertically in the middle editorial band
        let middleBottom: CGFloat = footerH + 12
        let middleTop: CGFloat = headerDividerY - 16
        let middleSpan = max(totalLyricsHeight, middleTop - middleBottom)
        var cursorY = middleBottom + (middleSpan + totalLyricsHeight) / 2

        for (idx, line) in displayLines.enumerated() {
            let h = measuredHeights[idx]
            cursorY -= h
            let isLead = (idx == 0 && displayLines.count > 1)
            let lineColor = isLead ? primaryTextColor : primaryTextColor.withAlphaComponent(0.92)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lyricFont,
                .foregroundColor: lineColor,
                .paragraphStyle: lyricParagraph
            ]
            (line as NSString).draw(
                with: NSRect(x: padX, y: cursorY, width: textWidth, height: h + 4),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            cursorY -= lineGap
        }

        // Bottom hairline + minimal ♪ NotchMuse brand signature
        ruleColor.setFill()
        NSRect(x: padX, y: 62, width: textWidth, height: 1).fill()

        let brandParagraph = NSMutableParagraphStyle()
        brandParagraph.alignment = .right
        let brandString = NSMutableAttributedString(
            string: "♪ ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12.5, weight: .bold),
                .foregroundColor: accentColor,
                .paragraphStyle: brandParagraph
            ]
        )
        brandString.append(NSAttributedString(
            string: "NotchMuse",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: secondaryTextColor,
                .paragraphStyle: brandParagraph
            ]
        ))
        brandString.draw(in: NSRect(x: logicalWidth - padX - 116, y: 34, width: 116, height: 18))

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else { return nil }
        let image = NSImage(size: NSSize(width: logicalWidth, height: logicalHeight))
        image.addRepresentation(rep)
        return (image, pngData)
    }

    private static func drawHeaderArtwork(_ artwork: NSImage?, in rect: NSRect, accentColor: NSColor, template: LyricShareTemplate) {
        let rounded = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(template == .warmAlabaster ? 0.16 : 0.36)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor(calibratedWhite: 0.09, alpha: 1).setFill()
        rounded.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        rounded.addClip()
        if let artwork, artwork.size.width > 0, artwork.size.height > 0 {
            let scale = max(rect.width / artwork.size.width, rect.height / artwork.size.height)
            let drawW = artwork.size.width * scale
            let drawH = artwork.size.height * scale
            let drawRect = NSRect(x: rect.midX - drawW / 2, y: rect.midY - drawH / 2, width: drawW, height: drawH)
            artwork.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // Graceful fallback miniature vinyl record emblem
            NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1).setFill()
            rect.fill()
            let center = NSPoint(x: rect.midX, y: rect.midY)
            for r: CGFloat in [22, 17, 12] {
                NSColor.white.withAlphaComponent(0.12).setStroke()
                let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                ring.lineWidth = 0.65
                ring.stroke()
            }
            accentColor.withAlphaComponent(0.94).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 7.5, y: center.y - 7.5, width: 15, height: 15)).fill()
            NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        let rimColor: NSColor = template == .warmAlabaster
            ? NSColor.black.withAlphaComponent(0.10)
            : NSColor.white.withAlphaComponent(0.16)
        rimColor.setStroke()
        rounded.lineWidth = 0.75
        rounded.stroke()
    }

    private static func drawBackground(in rect: NSRect, template: LyricShareTemplate) {
        switch template {
        case .vinylDark:
            NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.086, alpha: 1).setFill()
            rect.fill()
            if let glow = NSGradient(
                starting: NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 0.16),
                ending: NSColor.clear
            ) {
                glow.draw(
                    fromCenter: NSPoint(x: rect.maxX - 64, y: rect.maxY - 64),
                    radius: 8,
                    toCenter: NSPoint(x: rect.maxX - 64, y: rect.maxY - 64),
                    radius: 210,
                    options: []
                )
            }
            NSColor.white.withAlphaComponent(0.08).setStroke()
            let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 12, dy: 12), xRadius: 14, yRadius: 14)
            frame.lineWidth = 0.75
            frame.stroke()

        case .warmAlabaster:
            NSColor(calibratedRed: 0.961, green: 0.957, blue: 0.941, alpha: 1).setFill()
            rect.fill()
            if let warmth = NSGradient(
                starting: NSColor(calibratedRed: 0.92, green: 0.87, blue: 0.80, alpha: 0.45),
                ending: NSColor.clear
            ) {
                warmth.draw(
                    fromCenter: NSPoint(x: rect.minX + 60, y: rect.maxY - 40),
                    radius: 10,
                    toCenter: NSPoint(x: rect.minX + 60, y: rect.maxY - 40),
                    radius: 240,
                    options: []
                )
            }
            NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.14, alpha: 0.22).setStroke()
            let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 14, dy: 14), xRadius: 10, yRadius: 10)
            frame.lineWidth = 0.8
            frame.stroke()

        case .mistySage:
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.23, alpha: 1),
                NSColor(calibratedRed: 0.16, green: 0.34, blue: 0.31, alpha: 1),
                NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.18, alpha: 1)
            ])
            gradient?.draw(in: rect, angle: -55)
            if let mist = NSGradient(
                starting: NSColor(calibratedRed: 0.62, green: 0.92, blue: 0.82, alpha: 0.18),
                ending: NSColor.clear
            ) {
                mist.draw(
                    fromCenter: NSPoint(x: rect.maxX - 80, y: rect.maxY - 70),
                    radius: 10,
                    toCenter: NSPoint(x: rect.maxX - 80, y: rect.maxY - 70),
                    radius: 220,
                    options: []
                )
            }
            NSColor.white.withAlphaComponent(0.14).setStroke()
            let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 12, dy: 12), xRadius: 14, yRadius: 14)
            frame.lineWidth = 0.75
            frame.stroke()
        }
    }

    private static func drawOrnament(in rect: NSRect, template: LyricShareTemplate) {
        switch template {
        case .vinylDark:
            // Miniature concentric vinyl record in top-right corner
            let center = NSPoint(x: rect.maxX - 58, y: rect.maxY - 58)
            let outerR: CGFloat = 28
            NSColor(calibratedWhite: 0.05, alpha: 0.95).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)).fill()
            for r in stride(from: CGFloat(13), through: outerR - 2, by: 3.5) {
                NSColor.white.withAlphaComponent(0.10).setStroke()
                let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                ring.lineWidth = 0.6
                ring.stroke()
            }
            let labelR: CGFloat = 9
            NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 0.94).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - labelR, y: center.y - labelR, width: labelR * 2, height: labelR * 2)).fill()
            NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 2.2, y: center.y - 2.2, width: 4.4, height: 4.4)).fill()

        case .warmAlabaster:
            // Editorial caramel hairline + issue tag top right
            let tagAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold),
                .foregroundColor: NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.14, alpha: 0.82)
            ]
            ("LYRIC NOTE" as NSString).draw(at: NSPoint(x: rect.maxX - 102, y: rect.maxY - 52), withAttributes: tagAttrs)
            NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.14, alpha: 0.35).setFill()
            NSRect(x: rect.maxX - 102, y: rect.maxY - 57, width: 64, height: 1).fill()

        case .mistySage:
            // Subtle floating acoustic wave bars top right
            let heights: [CGFloat] = [8, 16, 11, 20, 13]
            let startX = rect.maxX - 76
            let baseY = rect.maxY - 62
            NSColor(calibratedRed: 0.62, green: 0.92, blue: 0.82, alpha: 0.72).setFill()
            for (i, h) in heights.enumerated() {
                let bar = NSRect(x: startX + CGFloat(i) * 7, y: baseY + (20 - h) / 2, width: 3.2, height: h)
                NSBezierPath(roundedRect: bar, xRadius: 1.6, yRadius: 1.6).fill()
            }
        }
    }
}

@MainActor
final class LyricSharePopoverController: NSViewController {
    private let lines: [LyricLine]
    private let trackTitle: String
    private let artistName: String
    private let albumName: String
    private let artworkImage: NSImage?
    private var selectedIndices: Set<Int>
    private var selectedTemplate: LyricShareTemplate = .vinylDark
    private var lastRendered: (image: NSImage, pngData: Data)?

    private let previewFrame = AppearanceSurfaceView()
    private let previewImageView = NSImageView()
    private let countLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private var templateButtons: [NSButton] = []
    private var lineCheckboxes: [NSButton] = []

    var debugPreviewImage: NSImage? { previewImageView.image }

    func debugSelectTemplate(_ template: LyricShareTemplate) {
        selectedTemplate = template
        refreshPreview()
    }

    init(lines: [LyricLine], activeIndex: Int, trackTitle: String, artistName: String, albumName: String = "", artworkImage: NSImage? = nil) {
        self.lines = lines
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumName = albumName
        self.artworkImage = artworkImage
        self.selectedIndices = Set(LyricShareCardRenderer.defaultSelectedIndices(linesCount: lines.count, activeIndex: activeIndex))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let isZh = AppPreferences.language == .simplifiedChinese
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 610, height: 456))

        // Left: Live @2x HD preview container + template switcher + actions
        let previewBadge = NSTextField(labelWithString: isZh ? "实时预览 · @2x 高清出图" : "Live Preview · @2x Retina PNG")
        previewBadge.font = .systemFont(ofSize: 11, weight: .medium)
        previewBadge.textColor = .secondaryLabelColor
        previewBadge.translatesAutoresizingMaskIntoConstraints = false

        previewFrame.wantsLayer = true
        previewFrame.surfaceColor = AppearanceSurfaceColors.deck
        previewFrame.surfaceBorderColor = AppearanceSurfaceColors.border
        previewFrame.layer?.cornerRadius = 12
        previewFrame.layer?.cornerCurve = .continuous
        previewFrame.layer?.borderWidth = 1
        previewFrame.shadow = NSShadow()
        previewFrame.layer?.shadowColor = NSColor.black.withAlphaComponent(0.24).cgColor
        previewFrame.layer?.shadowOpacity = 0.25
        previewFrame.layer?.shadowRadius = 10
        previewFrame.layer?.shadowOffset = CGSize(width: 0, height: -4)
        previewFrame.translatesAutoresizingMaskIntoConstraints = false

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 9
        previewImageView.layer?.cornerCurve = .continuous
        previewImageView.layer?.masksToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewFrame.addSubview(previewImageView)

        let templateRow = NSStackView()
        templateRow.orientation = .horizontal
        templateRow.distribution = .fillEqually
        templateRow.spacing = 6
        templateRow.translatesAutoresizingMaskIntoConstraints = false

        templateButtons = LyricShareTemplate.allCases.enumerated().map { idx, tpl in
            let btn = NSButton(title: tpl.displayName(isZh: isZh), target: self, action: #selector(templatePicked(_:)))
            btn.tag = idx
            btn.bezelStyle = .rounded
            btn.controlSize = .small
            return btn
        }
        templateButtons.forEach { templateRow.addArrangedSubview($0) }

        copyButton.title = isZh ? "复制图片到剪贴板" : "Copy Image"
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = .command
        copyButton.target = self
        copyButton.action = #selector(copyImageClicked)

        saveButton.title = isZh ? "保存为 PNG…" : "Save PNG…"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(savePNGClicked)

        let actionRow = NSStackView(views: [copyButton, saveButton])
        actionRow.orientation = .horizontal
        actionRow.distribution = .fillEqually
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        // Right: Lyric line checklist (1–6 lines)
        let listHeader = NSTextField(labelWithString: isZh ? "勾选 1–6 句歌词" : "Select 1–6 Lyric Lines")
        listHeader.font = .systemFont(ofSize: 12.5, weight: .semibold)
        listHeader.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        let checkStack = NSStackView()
        checkStack.orientation = .vertical
        checkStack.alignment = .leading
        checkStack.spacing = 6
        checkStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        checkStack.translatesAutoresizingMaskIntoConstraints = false

        lineCheckboxes = lines.enumerated().map { idx, line in
            let cb = NSButton(checkboxWithTitle: line.text, target: self, action: #selector(lineToggled(_:)))
            cb.tag = idx
            cb.state = selectedIndices.contains(idx) ? .on : .off
            cb.lineBreakMode = .byTruncatingTail
            cb.font = .systemFont(ofSize: 12)
            cb.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return cb
        }
        lineCheckboxes.forEach { cb in
            checkStack.addArrangedSubview(cb)
            cb.widthAnchor.constraint(lessThanOrEqualTo: checkStack.widthAnchor, constant: -12).isActive = true
        }

        let listDoc = NSView()
        listDoc.translatesAutoresizingMaskIntoConstraints = false
        listDoc.addSubview(checkStack)
        NSLayoutConstraint.activate([
            checkStack.leadingAnchor.constraint(equalTo: listDoc.leadingAnchor),
            checkStack.trailingAnchor.constraint(equalTo: listDoc.trailingAnchor),
            checkStack.topAnchor.constraint(equalTo: listDoc.topAnchor),
            checkStack.bottomAnchor.constraint(equalTo: listDoc.bottomAnchor)
        ])

        let listScroll = NSScrollView()
        listScroll.drawsBackground = false
        listScroll.hasVerticalScroller = true
        listScroll.autohidesScrollers = true
        listScroll.scrollerStyle = .overlay
        listScroll.verticalScroller = SlimOverlayScroller()
        listScroll.borderType = .bezelBorder
        listScroll.documentView = listDoc
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(previewBadge)
        root.addSubview(previewFrame)
        root.addSubview(templateRow)
        root.addSubview(actionRow)
        root.addSubview(listHeader)
        root.addSubview(countLabel)
        root.addSubview(listScroll)

        NSLayoutConstraint.activate([
            previewBadge.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            previewBadge.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            previewFrame.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            previewFrame.topAnchor.constraint(equalTo: previewBadge.bottomAnchor, constant: 6),
            previewFrame.widthAnchor.constraint(equalToConstant: 268),
            previewFrame.heightAnchor.constraint(equalToConstant: 336),

            previewImageView.leadingAnchor.constraint(equalTo: previewFrame.leadingAnchor, constant: 8),
            previewImageView.trailingAnchor.constraint(equalTo: previewFrame.trailingAnchor, constant: -8),
            previewImageView.topAnchor.constraint(equalTo: previewFrame.topAnchor, constant: 8),
            previewImageView.bottomAnchor.constraint(equalTo: previewFrame.bottomAnchor, constant: -8),

            templateRow.leadingAnchor.constraint(equalTo: previewFrame.leadingAnchor),
            templateRow.trailingAnchor.constraint(equalTo: previewFrame.trailingAnchor),
            templateRow.topAnchor.constraint(equalTo: previewFrame.bottomAnchor, constant: 10),

            actionRow.leadingAnchor.constraint(equalTo: previewFrame.leadingAnchor),
            actionRow.trailingAnchor.constraint(equalTo: previewFrame.trailingAnchor),
            actionRow.topAnchor.constraint(equalTo: templateRow.bottomAnchor, constant: 8),

            listHeader.leadingAnchor.constraint(equalTo: previewFrame.trailingAnchor, constant: 16),
            listHeader.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            countLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: listHeader.centerYAnchor),

            listScroll.leadingAnchor.constraint(equalTo: listHeader.leadingAnchor),
            listScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            listScroll.topAnchor.constraint(equalTo: listHeader.bottomAnchor, constant: 8),
            listScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            listDoc.widthAnchor.constraint(equalTo: listScroll.contentView.widthAnchor)
        ])

        self.view = root
        refreshPreview()
    }

    @objc private func templatePicked(_ sender: NSButton) {
        guard LyricShareTemplate.allCases.indices.contains(sender.tag) else { return }
        selectedTemplate = LyricShareTemplate.allCases[sender.tag]
        refreshPreview()
    }

    @objc private func lineToggled(_ sender: NSButton) {
        let idx = sender.tag
        if sender.state == .on {
            if selectedIndices.count >= 6 {
                sender.state = .off
                NSSound.beep()
                return
            }
            selectedIndices.insert(idx)
        } else {
            if selectedIndices.count <= 1 {
                sender.state = .on
                return
            }
            selectedIndices.remove(idx)
        }
        refreshPreview()
    }

    private func refreshPreview() {
        let isZh = AppPreferences.language == .simplifiedChinese
        let orderedLines = selectedIndices.sorted().compactMap { idx -> String? in
            guard lines.indices.contains(idx) else { return nil }
            return lines[idx].text
        }
        countLabel.stringValue = isZh ? "已选 \(orderedLines.count) / 6 句" : "\(orderedLines.count) / 6 selected"
        for (idx, btn) in templateButtons.enumerated() {
            btn.contentTintColor = (LyricShareTemplate.allCases[idx] == selectedTemplate) ? AppearanceSurfaceColors.accent : nil
        }
        if let rendered = LyricShareCardRenderer.renderPNG(
            lines: orderedLines,
            trackTitle: trackTitle,
            artistName: artistName,
            albumName: albumName,
            artworkImage: artworkImage,
            template: selectedTemplate
        ) {
            lastRendered = rendered
            previewImageView.image = rendered.image
        }
    }

    @objc private func copyImageClicked() {
        guard let rendered = lastRendered else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(rendered.pngData, forType: .png)
        if let tiff = rendered.image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        let isZh = AppPreferences.language == .simplifiedChinese
        let orig = isZh ? "复制图片到剪贴板" : "Copy Image"
        copyButton.title = isZh ? "已复制 ✓" : "Copied ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.copyButton.title = orig
        }
    }

    @objc private func savePNGClicked() {
        guard let rendered = lastRendered else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let safeName = trackTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = "NotchMuse-\(safeName.isEmpty ? "Lyrics" : safeName).png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? rendered.pngData.write(to: url, options: .atomic)
        }
    }
}
