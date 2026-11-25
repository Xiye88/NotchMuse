import AppKit
import Darwin
import QuartzCore
import LyricsCore

enum MissingLyricsAnimationStyle: String, CaseIterable, Equatable, Sendable {
    case vinylSeek = "Vinyl Seek (Default)"
    case cassetteB = "Cassette Side B"
    case runawayNotes = "Runaway Notes"

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "黑胶寻轨（默认）"
        case (.cassetteB, .simplifiedChinese): return "复古磁带"
        case (.runawayNotes, .simplifiedChinese): return "小音符逃跑"
        default: return rawValue
        }
    }

    func playfulCaption(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "404 · 唱针没找到这首歌的词，正在黑胶纹路里打捞…"
        case (.cassetteB, .simplifiedChinese): return "404 · 歌词走失在磁带 B 面"
        case (.runawayNotes, .simplifiedChinese): return "歌词溜走了，这首大概是纯音乐？"
        case (.vinylSeek, _): return "404 · Tonearm couldn't find lyrics in the grooves…"
        case (.cassetteB, _): return "404 · Lyrics wandered off to Cassette Side B"
        case (.runawayNotes, _): return "Lyrics ran away — maybe an instrumental?"
        }
    }

    func shortBarCaption(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.vinylSeek, .simplifiedChinese): return "歌词跑丢了…"
        case (.cassetteB, .simplifiedChinese): return "歌词走失在磁带B面…"
        case (.runawayNotes, .simplifiedChinese): return "歌词溜走了，纯享旋律~"
        case (.vinylSeek, _): return "Lyrics wandered off…"
        case (.cassetteB, _): return "Lyrics lost on Side B…"
        case (.runawayNotes, _): return "Lyrics slipped away~"
        }
    }
}

enum MediaTransportCommand: Sendable {
    case previous
    case playPause
    case next

    var mediaRemoteCode: UInt32 {
        switch self {
        case .playPause: return 2 // kMRTogglePlayPause
        case .next: return 4      // kMRNextTrack
        case .previous: return 5  // kMRPreviousTrack
        }
    }
}

enum SystemMediaTransport {
    private typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> DarwinBoolean

    private static let sendCommandSymbol: SendCommandFn? = {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym = dlsym(handle, "MRMediaRemoteSendCommand") else {
            return nil
        }
        return unsafeBitCast(sym, to: SendCommandFn.self)
    }()

    static var isMediaRemoteCommandAvailable: Bool {
        sendCommandSymbol != nil
    }

    @discardableResult
    static func send(_ command: MediaTransportCommand, activeSource: PlayerSource?) -> Bool {
        // 1. Primary: Private MediaRemote.framework MRMediaRemoteSendCommand (works across Soda, NetEase, QQ, Kugou, YouTube Music, Spotify, Apple Music)
        if let sendFn = sendCommandSymbol {
            if sendFn(command.mediaRemoteCode, nil).boolValue {
                return true
            }
        }

        // 2. Fallback: AppleScript for Spotify & Apple Music
        if activeSource == .spotify {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Spotify\" to \(verb)") { return true }
        } else if activeSource == .appleMusic {
            let verb: String
            switch command {
            case .previous: verb = "previous track"
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            }
            if runAppleScript("tell application \"Music\" to \(verb)") { return true }
        }

        // 3. Final fallback: hardware media key event
        let keyCode: Int
        switch command {
        case .playPause: keyCode = 16
        case .next: keyCode = 17
        case .previous: keyCode = 18
        }
        postMediaKey(keyCode)
        return true
    }

    private static func postMediaKey(_ keyCode: Int) {
        for isDown in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xa00 : 0xb00)
            let data1 = (keyCode << 16) | (isDown ? 0xa00 : 0xb00)
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent {
                event.post(tap: .cghidEventTap)
            }
        }
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }
}

@MainActor
final class IdleVinylWaveView: NSView {
    private let stageView = NSView()
    private let label = NSTextField(labelWithString: "")
    private var ringLayers: [CAShapeLayer] = []
    private var barLayers: [CALayer] = []
    private var isActive = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        stageView.wantsLayer = true
        stageView.layer?.masksToBounds = false
        stageView.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = AppPreferences.language == .simplifiedChinese ? "等待播放音乐…" : "Waiting for music…"
        label.font = .systemFont(ofSize: 13.5, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stageView)
        addSubview(label)
        NSLayoutConstraint.activate([
            stageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -24),
            stageView.widthAnchor.constraint(equalToConstant: 96),
            stageView.heightAnchor.constraint(equalToConstant: 96),

            label.topAnchor.constraint(equalTo: stageView.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        rebuildArtwork()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopAnimations() }
        else if isActive && !isHidden { startAnimations() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildArtwork()
        if isActive && !isHidden { startAnimations() }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active && !isHidden && window != nil {
            startAnimations()
        } else {
            stopAnimations()
        }
    }

    private func stopAnimations() {
        ringLayers.forEach { $0.removeAllAnimations() }
        barLayers.forEach { $0.removeAllAnimations() }
    }

    private func rebuildArtwork() {
        stopAnimations()
        ringLayers.removeAll()
        barLayers.removeAll()
        stageView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let root = stageView.layer else { return }

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = AppearanceSurfaceColors.accent.cgColor
            for (idx, radius) in [CGFloat(22), CGFloat(32), CGFloat(42)].enumerated() {
                let ring = CAShapeLayer()
                ring.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
                ring.position = CGPoint(x: 48, y: 48)
                ring.path = CGPath(ellipseIn: ring.bounds, transform: nil)
                ring.fillColor = nil
                ring.strokeColor = AppearanceSurfaceColors.accent.withAlphaComponent(0.32 - CGFloat(idx) * 0.08).cgColor
                ring.lineWidth = 1.1
                root.addSublayer(ring)
                ringLayers.append(ring)
            }

            // 3 soft breathing warm-amber bars in the center
            for i in 0..<3 {
                let bar = CALayer()
                bar.anchorPoint = CGPoint(x: 0.5, y: 0)
                bar.bounds = CGRect(x: 0, y: 0, width: 3, height: 8)
                bar.position = CGPoint(x: 41 + CGFloat(i) * 7, y: 40)
                bar.cornerRadius = 1.5
                bar.backgroundColor = accent
                root.addSublayer(bar)
                barLayers.append(bar)
            }
        }
    }

    private func startAnimations() {
        stopAnimations()
        for (idx, ring) in ringLayers.enumerated() {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.94
            scale.toValue = 1.07
            scale.duration = 2.4 + Double(idx) * 0.45
            scale.autoreverses = true
            scale.repeatCount = .infinity
            scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ring.add(scale, forKey: "breathScale")

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.45
            fade.toValue = 1.0
            fade.duration = 2.4 + Double(idx) * 0.45
            fade.autoreverses = true
            fade.repeatCount = .infinity
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ring.add(fade, forKey: "breathFade")
        }
        let heights: [CGFloat] = [14, 20, 12]
        let durations: [CFTimeInterval] = [1.1, 1.4, 0.95]
        for (idx, bar) in barLayers.enumerated() {
            let pulse = CABasicAnimation(keyPath: "bounds.size.height")
            pulse.fromValue = 5
            pulse.toValue = heights[idx]
            pulse.duration = durations[idx]
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(pulse, forKey: "idleBar")
        }
    }
}

@MainActor
final class MissingLyricsAnimationView: NSView {
    var style: MissingLyricsAnimationStyle = .vinylSeek {
        didSet {
            if style != oldValue {
                rebuildArtwork()
                updateCaption()
                if isActive { startAnimations() }
            }
        }
    }
    var isIdlePreview: Bool = false {
        didSet {
            if isIdlePreview != oldValue {
                updateCaption()
            }
        }
    }
    var onRetry: (() -> Void)?

    private let stageView = NSView()
    private let captionLabel = NSTextField(wrappingLabelWithString: "")
    private let retryButton = NSButton(title: "", target: nil, action: nil)
    private var isActive = false
    private var animatedLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        stageView.wantsLayer = true
        stageView.layer?.masksToBounds = false
        stageView.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.alignment = .center
        captionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        retryButton.title = AppPreferences.language == .simplifiedChinese ? "重试匹配" : "Retry Match"
        retryButton.bezelStyle = .rounded
        retryButton.controlSize = .regular
        retryButton.target = self
        retryButton.action = #selector(retryClicked)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stageView)
        addSubview(captionLabel)
        addSubview(retryButton)

        NSLayoutConstraint.activate([
            stageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -36),
            stageView.widthAnchor.constraint(equalToConstant: 140),
            stageView.heightAnchor.constraint(equalToConstant: 96),

            captionLabel.topAnchor.constraint(equalTo: stageView.bottomAnchor, constant: 14),
            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),

            retryButton.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 14),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        rebuildArtwork()
        updateCaption()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimations()
        } else if isActive && !isHidden {
            startAnimations()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildArtwork()
        if isActive && !isHidden { startAnimations() }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active && !isHidden && window != nil {
            startAnimations()
        } else {
            stopAnimations()
        }
    }

    @objc private func retryClicked() {
        onRetry?()
    }

    private func updateCaption() {
        if isIdlePreview {
            captionLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "等待播放音乐…" : "Waiting for music…"
            retryButton.isHidden = true
        } else {
            captionLabel.stringValue = style.playfulCaption()
            retryButton.isHidden = false
        }
    }

    private func stopAnimations() {
        animatedLayers.forEach { $0.removeAllAnimations() }
    }

    private func rebuildArtwork() {
        stopAnimations()
        animatedLayers.removeAll()
        stageView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let root = stageView.layer else { return }

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = AppearanceSurfaceColors.accent.cgColor
            let ink = NSColor.labelColor.withAlphaComponent(0.75).cgColor
            let subtle = NSColor.labelColor.withAlphaComponent(0.18).cgColor

            switch style {
            case .vinylSeek:
                let disc = CALayer()
                disc.bounds = CGRect(x: 0, y: 0, width: 64, height: 64)
                disc.position = CGPoint(x: 56, y: 42)
                disc.cornerRadius = 32
                disc.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1).cgColor
                disc.borderWidth = 1
                disc.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
                for r: CGFloat in [27, 22, 17] {
                    let g = CAShapeLayer()
                    g.path = CGPath(ellipseIn: CGRect(x: 32 - r, y: 32 - r, width: r * 2, height: r * 2), transform: nil)
                    g.fillColor = nil
                    g.strokeColor = NSColor.white.withAlphaComponent(0.10).cgColor
                    g.lineWidth = 0.6
                    disc.addSublayer(g)
                }
                let centerLabel = CAShapeLayer()
                centerLabel.path = CGPath(ellipseIn: CGRect(x: 22, y: 22, width: 20, height: 20), transform: nil)
                centerLabel.fillColor = accent
                disc.addSublayer(centerLabel)
                let hole = CAShapeLayer()
                hole.path = CGPath(ellipseIn: CGRect(x: 29.5, y: 29.5, width: 5, height: 5), transform: nil)
                hole.fillColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1).cgColor
                disc.addSublayer(hole)
                root.addSublayer(disc)
                animatedLayers.append(disc)

                let arm = CALayer()
                arm.bounds = CGRect(x: 0, y: 0, width: 24, height: 42)
                arm.anchorPoint = CGPoint(x: 0.8, y: 0.9)
                arm.position = CGPoint(x: 100, y: 66)
                let armLine = CAShapeLayer()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 19, y: 38))
                p.addLine(to: CGPoint(x: 16, y: 14))
                p.addLine(to: CGPoint(x: 8, y: 6))
                armLine.path = p
                armLine.fillColor = nil
                armLine.strokeColor = ink
                armLine.lineWidth = 2
                armLine.lineCap = .round
                arm.addSublayer(armLine)
                let head = CAShapeLayer()
                head.path = CGPath(roundedRect: CGRect(x: 5, y: 3, width: 6, height: 6), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
                head.fillColor = accent
                arm.addSublayer(head)
                root.addSublayer(arm)
                animatedLayers.append(arm)

                let note = makeTextLayer("? ♪", size: 15, color: accent)
                note.position = CGPoint(x: 112, y: 78)
                root.addSublayer(note)
                animatedLayers.append(note)

            case .cassetteB:
                let body = CAShapeLayer()
                body.path = CGPath(roundedRect: CGRect(x: 24, y: 24, width: 92, height: 56), cornerWidth: 8, cornerHeight: 8, transform: nil)
                body.fillColor = AppearanceSurfaceColors.card.cgColor
                body.strokeColor = ink
                body.lineWidth = 1.25
                root.addSublayer(body)

                let windowBand = CAShapeLayer()
                windowBand.path = CGPath(roundedRect: CGRect(x: 34, y: 42, width: 72, height: 22), cornerWidth: 4, cornerHeight: 4, transform: nil)
                windowBand.fillColor = subtle
                root.addSublayer(windowBand)

                for cx: CGFloat in [52, 88] {
                    let reel = CAShapeLayer()
                    reel.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
                    reel.position = CGPoint(x: cx, y: 53)
                    let rp = CGMutablePath()
                    rp.addEllipse(in: CGRect(x: 1, y: 1, width: 14, height: 14))
                    rp.move(to: CGPoint(x: 8, y: 2)); rp.addLine(to: CGPoint(x: 8, y: 14))
                    rp.move(to: CGPoint(x: 2, y: 8)); rp.addLine(to: CGPoint(x: 14, y: 8))
                    reel.path = rp
                    reel.fillColor = nil
                    reel.strokeColor = accent
                    reel.lineWidth = 1.4
                    root.addSublayer(reel)
                    animatedLayers.append(reel)
                }

                let ribbon = CAShapeLayer()
                let wp = CGMutablePath()
                wp.move(to: CGPoint(x: 42, y: 24))
                wp.addCurve(to: CGPoint(x: 98, y: 24), control1: CGPoint(x: 56, y: 4), control2: CGPoint(x: 82, y: 34))
                ribbon.path = wp
                ribbon.fillColor = nil
                ribbon.strokeColor = accent
                ribbon.lineWidth = 1.6
                ribbon.lineCap = .round
                ribbon.bounds = CGRect(x: 0, y: 0, width: 140, height: 40)
                ribbon.position = CGPoint(x: 70, y: 20)
                root.addSublayer(ribbon)
                animatedLayers.append(ribbon)

            case .runawayNotes:
                let n1 = makeTextLayer("♪", size: 24, color: accent)
                n1.position = CGPoint(x: 52, y: 46)
                root.addSublayer(n1)
                animatedLayers.append(n1)

                let n2 = makeTextLayer("♫", size: 22, color: accent)
                n2.position = CGPoint(x: 82, y: 50)
                root.addSublayer(n2)
                animatedLayers.append(n2)

                let glass = makeTextLayer("⌕", size: 26, color: ink)
                glass.position = CGPoint(x: 108, y: 44)
                root.addSublayer(glass)
                animatedLayers.append(glass)
            }
        }
    }

    private func makeTextLayer(_ text: String, size: CGFloat, color: CGColor) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = text
        layer.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        layer.fontSize = size
        layer.foregroundColor = color
        layer.alignmentMode = .center
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.bounds = CGRect(x: 0, y: 0, width: 42, height: 32)
        return layer
    }

    private func startAnimations() {
        stopAnimations()
        guard !animatedLayers.isEmpty else { return }

        switch style {
        case .vinylSeek:
            if animatedLayers.indices.contains(0) {
                let wobble = CABasicAnimation(keyPath: "transform.rotation.z")
                wobble.fromValue = -0.10
                wobble.toValue = 0.10
                wobble.duration = 1.4
                wobble.autoreverses = true
                wobble.repeatCount = .infinity
                wobble.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[0].add(wobble, forKey: "wobble")
            }
            if animatedLayers.indices.contains(1) {
                let seek = CABasicAnimation(keyPath: "transform.rotation.z")
                seek.fromValue = -0.05
                seek.toValue = 0.22
                seek.duration = 1.8
                seek.autoreverses = true
                seek.repeatCount = .infinity
                seek.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[1].add(seek, forKey: "seek")
            }
            if animatedLayers.indices.contains(2) {
                let floatAnim = CABasicAnimation(keyPath: "position.y")
                floatAnim.fromValue = 74
                floatAnim.toValue = 84
                floatAnim.duration = 1.2
                floatAnim.autoreverses = true
                floatAnim.repeatCount = .infinity
                floatAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(floatAnim, forKey: "float")
            }

        case .cassetteB:
            for i in 0..<min(2, animatedLayers.count) {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = CGFloat.pi * 2
                spin.duration = 2.6
                spin.repeatCount = .infinity
                animatedLayers[i].add(spin, forKey: "reelSpin")
            }
            if animatedLayers.indices.contains(2) {
                let sway = CABasicAnimation(keyPath: "position.y")
                sway.fromValue = 18
                sway.toValue = 23
                sway.duration = 1.1
                sway.autoreverses = true
                sway.repeatCount = .infinity
                sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(sway, forKey: "sway")
            }

        case .runawayNotes:
            for (idx, layer) in animatedLayers.prefix(2).enumerated() {
                let hop = CAKeyframeAnimation(keyPath: "position.y")
                hop.values = [44, 58, 44]
                hop.duration = 0.72 + Double(idx) * 0.14
                hop.repeatCount = .infinity
                hop.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(hop, forKey: "hop")

                let drift = CABasicAnimation(keyPath: "position.x")
                drift.fromValue = (idx == 0 ? 44 : 74)
                drift.toValue = (idx == 0 ? 60 : 90)
                drift.duration = 1.4
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(drift, forKey: "drift")
            }
            if animatedLayers.indices.contains(2) {
                let chase = CABasicAnimation(keyPath: "transform.rotation.z")
                chase.fromValue = -0.18
                chase.toValue = 0.18
                chase.duration = 0.9
                chase.autoreverses = true
                chase.repeatCount = .infinity
                chase.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animatedLayers[2].add(chase, forKey: "chase")
            }
        }
    }
}

@MainActor
private final class SweepLyricLineView: NSView {
    let primaryText: String
    let translationText: String?

    var isActive: Bool = false { didSet { if isActive != oldValue { invalidateIntrinsicContentSize(); needsDisplay = true } } }
    var distanceFromActive: Int = 99 { didSet { if distanceFromActive != oldValue { needsDisplay = true } } }
    var sweepProgress: CGFloat = 0 { didSet { if abs(sweepProgress - oldValue) > 0.004 { needsDisplay = true } } }
    var customSweepColor: NSColor? { didSet { needsDisplay = true } }
    var customNormalColor: NSColor? { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    init(primaryText: String, translationText: String?) {
        self.primaryText = primaryText
        self.translationText = translationText
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        let width = max(220, bounds.width > 0 ? bounds.width : 420)
        let font = currentFont()
        let primaryHeight = measuredHeight(primaryText, font: font, width: width)
        let transHeight = translationText.map { measuredHeight($0, font: .systemFont(ofSize: isActive ? 13 : 11.5, weight: .regular), width: width) + 4 } ?? 0
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(primaryHeight + transHeight + 6))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(newSize.width - frame.width) > 1
        super.setFrameSize(newSize)
        if widthChanged { invalidateIntrinsicContentSize() }
    }

    private func currentFont() -> NSFont {
        if isActive { return .systemFont(ofSize: 21, weight: .bold) }
        if distanceFromActive == 1 { return .systemFont(ofSize: 15.5, weight: .medium) }
        return .systemFont(ofSize: 14.5, weight: .regular)
    }

    private func measuredHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style]
        )
        return rect.height
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let font = currentFont()
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byWordWrapping

            let baseNormal = customNormalColor ?? NSColor.labelColor
            let primaryH = measuredHeight(primaryText, font: font, width: bounds.width)
            let primaryRect = NSRect(x: 0, y: 2, width: bounds.width, height: ceil(primaryH + 2))

            if isActive {
                let sweepColor = customSweepColor ?? AppearanceSurfaceColors.accent
                let unsweptColor = baseNormal.withAlphaComponent(0.32)
                (primaryText as NSString).draw(
                    with: primaryRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: unsweptColor, .paragraphStyle: style]
                )

                // Compute tight text bounding width so sweep tracks the actual text span left-to-right
                let lineSize = (primaryText as NSString).size(withAttributes: [.font: font])
                let textWidth = min(bounds.width, lineSize.width + 6)
                let startX = max(0, (bounds.width - textWidth) / 2)
                let clamped = min(1, max(0, sweepProgress))
                let clipRect = NSRect(x: startX, y: primaryRect.minY - 4, width: textWidth * clamped, height: primaryRect.height + 8)

                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: clipRect).addClip()
                let glow = NSShadow()
                glow.shadowColor = sweepColor.withAlphaComponent(0.40)
                glow.shadowBlurRadius = 8
                glow.shadowOffset = .zero
                (primaryText as NSString).draw(
                    with: primaryRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: sweepColor, .paragraphStyle: style, .shadow: glow]
                )
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let alpha: CGFloat = distanceFromActive == 1 ? 0.62 : 0.34
                let color = customNormalColor?.withAlphaComponent(alpha) ?? (distanceFromActive == 1 ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor)
                (primaryText as NSString).draw(
                    with: primaryRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
                )
            }

            if let translationText {
                let transFont = NSFont.systemFont(ofSize: isActive ? 13 : 11.5, weight: .regular)
                let transColor = (customNormalColor ?? NSColor.secondaryLabelColor).withAlphaComponent(isActive ? 0.78 : 0.40)
                let transRect = NSRect(x: 0, y: primaryRect.maxY + 2, width: bounds.width, height: bounds.height - primaryRect.maxY - 2)
                (translationText as NSString).draw(
                    with: transRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: transFont, .foregroundColor: transColor, .paragraphStyle: style]
                )
            }
        }
    }
}

enum ImmersiveLyricsThemePreset: String, CaseIterable, Equatable, Sendable {
    case followTheme = "Follow Theme"
    case warmAmber = "Warm Amber Vinyl"
    case midnightAurora = "Midnight Aurora"
    case pineGlow = "Pine Glow"
    case warmPaper = "Warm Paper"
    case sakuraMist = "Sakura Mist"

    func displayName(language: AppLanguage = AppPreferences.language) -> String {
        switch (self, language) {
        case (.followTheme, .simplifiedChinese): return "跟随主题"
        case (.warmAmber, .simplifiedChinese): return "暖琥珀黑胶"
        case (.midnightAurora, .simplifiedChinese): return "午夜极光"
        case (.pineGlow, .simplifiedChinese): return "松林微光"
        case (.warmPaper, .simplifiedChinese): return "暖纸墨黑"
        case (.sakuraMist, .simplifiedChinese): return "樱花粉雾"
        default: return rawValue
        }
    }

    var backgroundColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.086, alpha: 1)      // #141416
        case .midnightAurora: return NSColor(calibratedRed: 0.059, green: 0.090, blue: 0.165, alpha: 1) // #0F172A
        case .pineGlow: return NSColor(calibratedRed: 0.059, green: 0.122, blue: 0.102, alpha: 1)       // #0F1F1A
        case .warmPaper: return NSColor(calibratedRed: 0.973, green: 0.965, blue: 0.941, alpha: 1)      // #F8F6F0
        case .sakuraMist: return NSColor(calibratedRed: 1.0, green: 0.961, blue: 0.969, alpha: 1)       // #FFF5F7
        }
    }

    var sweepColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 1.0, green: 0.541, blue: 0.212, alpha: 1)        // #FF8A36
        case .midnightAurora: return NSColor(calibratedRed: 0.220, green: 0.741, blue: 0.973, alpha: 1) // #38BDF8
        case .pineGlow: return NSColor(calibratedRed: 0.204, green: 0.827, blue: 0.600, alpha: 1)       // #34D399
        case .warmPaper: return NSColor(calibratedRed: 0.851, green: 0.420, blue: 0.153, alpha: 1)      // #D96B27
        case .sakuraMist: return NSColor(calibratedRed: 0.882, green: 0.114, blue: 0.282, alpha: 1)     // #E11D48
        }
    }

    var normalTextColor: NSColor? {
        switch self {
        case .followTheme: return nil
        case .warmAmber: return NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.85, alpha: 1)
        case .midnightAurora: return NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.92, alpha: 1)
        case .pineGlow: return NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.79, alpha: 1)
        case .warmPaper: return NSColor(calibratedRed: 0.20, green: 0.19, blue: 0.17, alpha: 1)
        case .sakuraMist: return NSColor(calibratedRed: 0.36, green: 0.29, blue: 0.32, alpha: 1)
        }
    }
}

@MainActor
private final class ThemeSwatchDotButton: NSButton {
    let preset: ImmersiveLyricsThemePreset
    var isSelectedPreset: Bool = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(preset: ImmersiveLyricsThemePreset, target: AnyObject?, action: Selector?) {
        self.preset = preset
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.target = target
        self.action = action
        self.toolTip = preset.displayName()
        self.setAccessibilityLabel(preset.displayName())
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 18),
            heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let outerRect = bounds.insetBy(dx: 1.2, dy: 1.2)
            let dotRect = bounds.insetBy(dx: 3.2, dy: 3.2)

            if preset == .followTheme {
                // Half-dark / half-light split circle
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(ovalIn: dotRect).addClip()
                NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
                NSRect(x: dotRect.minX, y: dotRect.minY, width: dotRect.width / 2, height: dotRect.height).fill()
                NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
                NSRect(x: dotRect.midX, y: dotRect.minY, width: dotRect.width / 2, height: dotRect.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            } else {
                (preset.backgroundColor ?? .black).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                if let accent = preset.sweepColor {
                    accent.setFill()
                    NSBezierPath(ovalIn: dotRect.insetBy(dx: 3.2, dy: 3.2)).fill()
                }
            }

            // Subtle inner rim
            NSColor.labelColor.withAlphaComponent(0.22).setStroke()
            let innerRim = NSBezierPath(ovalIn: dotRect)
            innerRim.lineWidth = 0.6
            innerRim.stroke()

            // Crisp selected / hover ring
            if isSelectedPreset {
                (preset.sweepColor ?? AppearanceSurfaceColors.accent).setStroke()
                let ring = NSBezierPath(ovalIn: outerRect)
                ring.lineWidth = 1.6
                ring.stroke()
            } else if isHovered {
                NSColor.labelColor.withAlphaComponent(0.45).setStroke()
                let ring = NSBezierPath(ovalIn: outerRect)
                ring.lineWidth = 1.0
                ring.stroke()
            }
        }
    }
}

@MainActor
private final class TransportButton: NSButton {
    let isPrimary: Bool
    private var tracking: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    init(symbol: String, size: CGFloat, isPrimary: Bool, target: AnyObject?, action: Selector?) {
        self.isPrimary = isPrimary
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.isEnabled = true
        self.target = target
        self.action = action
        self.wantsLayer = true
        self.layer?.cornerRadius = isPrimary ? 16 : 13
        self.layer?.cornerCurve = .continuous
        self.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        self.translatesAutoresizingMaskIntoConstraints = false
        refreshStyle()
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshStyle()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        refreshStyle()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        refreshStyle()
        super.mouseDown(with: event)
        isPressed = false
        refreshStyle()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshStyle()
    }

    func refreshStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isPrimary {
                contentTintColor = .white
                let base = AppearanceSurfaceColors.accent
                if isPressed {
                    layer?.backgroundColor = base.blended(withFraction: 0.25, of: .black)?.cgColor ?? base.cgColor
                    alphaValue = 0.82
                } else if isHovered {
                    layer?.backgroundColor = base.blended(withFraction: 0.14, of: .white)?.cgColor ?? base.cgColor
                    alphaValue = 1.0
                } else {
                    layer?.backgroundColor = base.cgColor
                    alphaValue = 1.0
                }
            } else {
                contentTintColor = isHovered ? .labelColor : .secondaryLabelColor
                if isPressed {
                    layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.18).cgColor
                    alphaValue = 0.72
                } else if isHovered {
                    layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
                    alphaValue = 1.0
                } else {
                    layer?.backgroundColor = NSColor.clear.cgColor
                    alphaValue = 1.0
                }
            }
        }
    }
}

@MainActor
final class ImmersiveLyricsView: NSView {
    var onTransportCommand: ((MediaTransportCommand) -> Void)?
    var onRetryMatch: (() -> Void)?

    private let stageBackground = AppearanceSurfaceView()
    private let scrollView = ImmersiveLyricsScrollView()
    private let documentView = FlippedImmersiveDocumentView()
    private let linesStack = NSStackView()
    private var lineViews: [SweepLyricLineView] = []
    private var currentLines: [LyricLine] = []
    private var activeIndex: Int = -1
    private var userBrowsingUntil: TimeInterval = 0

    let missingView = MissingLyricsAnimationView()
    let idleWaveView = IdleVinylWaveView()

    private let transportBar = AppearanceSurfaceView()
    private let progressTrack = NSView()
    private let progressFill = NSView()
    private var progressFillWidth: NSLayoutConstraint?
    private let trackTitleLabel = NSTextField(labelWithString: "")
    private let trackArtistLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    private lazy var prevButton = TransportButton(symbol: "backward.fill", size: 13, isPrimary: false, target: self, action: #selector(prevClicked))
    private lazy var playPauseButton = TransportButton(symbol: "play.fill", size: 14, isPrimary: true, target: self, action: #selector(playPauseClicked))
    private lazy var nextButton = TransportButton(symbol: "forward.fill", size: 13, isPrimary: false, target: self, action: #selector(nextClicked))
    private var swatchButtons: [ThemeSwatchDotButton] = []
    private var isPlayingState = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
        applyCustomColors()
    }

    required init?(coder: NSCoder) { nil }

    var animationStyle: MissingLyricsAnimationStyle {
        get { missingView.style }
        set { missingView.style = newValue }
    }

    func setStageVisible(_ visible: Bool) {
        isHidden = !visible
        missingView.setActive(visible && !missingView.isHidden)
        idleWaveView.setActive(visible && !idleWaveView.isHidden)
        if visible && activeIndex >= 0 {
            scrollActiveLineToCenterIfAllowed(animated: false)
        }
    }

    func applyCustomColors() {
        let preset = AppPreferences.immersiveThemePreset
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if let customBg = preset.backgroundColor {
                stageBackground.surfaceColor = customBg
                stageBackground.layer?.cornerRadius = 12
                stageBackground.layer?.borderWidth = 0.5
                stageBackground.surfaceBorderColor = AppearanceSurfaceColors.border
            } else {
                stageBackground.surfaceColor = .clear
                stageBackground.layer?.borderWidth = 0
                stageBackground.surfaceBorderColor = .clear
            }
            for btn in swatchButtons {
                btn.isSelectedPreset = (btn.preset == preset)
            }
            let sweep = preset.sweepColor
            let normal = preset.normalTextColor
            for view in lineViews {
                view.customSweepColor = sweep
                view.customNormalColor = normal
            }
        }
    }

    private func setupLayout() {
        let isZh = AppPreferences.language == .simplifiedChinese

        stageBackground.wantsLayer = true
        stageBackground.layer?.cornerCurve = .continuous
        stageBackground.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.onUserScroll = { [weak self] in
            self?.userBrowsingUntil = ProcessInfo.processInfo.systemUptime + 4.0
        }

        linesStack.orientation = .vertical
        linesStack.alignment = .centerX
        linesStack.spacing = 18
        linesStack.edgeInsets = NSEdgeInsets(top: 180, left: 28, bottom: 180, right: 28)
        linesStack.translatesAutoresizingMaskIntoConstraints = false

        documentView.addSubview(linesStack)
        scrollView.documentView = documentView

        missingView.isIdlePreview = true
        missingView.isHidden = false
        missingView.onRetry = { [weak self] in self?.onRetryMatch?() }

        idleWaveView.isHidden = true

        transportBar.wantsLayer = true
        transportBar.surfaceColor = AppearanceSurfaceColors.card
        transportBar.surfaceBorderColor = AppearanceSurfaceColors.border
        transportBar.layer?.cornerRadius = 12
        transportBar.layer?.cornerCurve = .continuous
        transportBar.layer?.borderWidth = 0.5
        transportBar.translatesAutoresizingMaskIntoConstraints = false

        progressTrack.wantsLayer = true
        progressTrack.layer?.cornerRadius = 1.5
        progressTrack.translatesAutoresizingMaskIntoConstraints = false

        progressFill.wantsLayer = true
        progressFill.layer?.cornerRadius = 1.5
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        trackTitleLabel.stringValue = isZh ? "未在播放" : "Not Playing"
        trackTitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        trackTitleLabel.textColor = .labelColor
        trackTitleLabel.lineBreakMode = .byTruncatingTail
        trackTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        trackArtistLabel.stringValue = "NotchMuse"
        trackArtistLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        trackArtistLabel.textColor = .secondaryLabelColor
        trackArtistLabel.lineBreakMode = .byTruncatingTail
        trackArtistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trackArtistLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        swatchButtons = ImmersiveLyricsThemePreset.allCases.map { preset in
            ThemeSwatchDotButton(preset: preset, target: self, action: #selector(swatchClicked(_:)))
        }
        let swatchRow = NSStackView(views: swatchButtons)
        swatchRow.orientation = .horizontal
        swatchRow.alignment = .centerY
        swatchRow.spacing = 4
        swatchRow.translatesAutoresizingMaskIntoConstraints = false

        let rightControls = NSStackView(views: [swatchRow, timeLabel])
        rightControls.orientation = .horizontal
        rightControls.alignment = .centerY
        rightControls.spacing = 8
        rightControls.translatesAutoresizingMaskIntoConstraints = false

        transportBar.addSubview(progressTrack)
        transportBar.addSubview(trackTitleLabel)
        transportBar.addSubview(trackArtistLabel)
        transportBar.addSubview(prevButton)
        transportBar.addSubview(playPauseButton)
        transportBar.addSubview(nextButton)
        transportBar.addSubview(rightControls)

        addSubview(stageBackground)
        addSubview(scrollView)
        addSubview(missingView)
        addSubview(idleWaveView)
        addSubview(transportBar)

        let widthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidth = widthConstraint

        NSLayoutConstraint.activate([
            stageBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stageBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stageBackground.topAnchor.constraint(equalTo: topAnchor),
            stageBackground.bottomAnchor.constraint(equalTo: transportBar.topAnchor, constant: -10),

            scrollView.leadingAnchor.constraint(equalTo: stageBackground.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: stageBackground.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: stageBackground.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: stageBackground.bottomAnchor),

            linesStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            linesStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            linesStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            linesStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            missingView.leadingAnchor.constraint(equalTo: stageBackground.leadingAnchor),
            missingView.trailingAnchor.constraint(equalTo: stageBackground.trailingAnchor),
            missingView.topAnchor.constraint(equalTo: stageBackground.topAnchor),
            missingView.bottomAnchor.constraint(equalTo: stageBackground.bottomAnchor),

            idleWaveView.leadingAnchor.constraint(equalTo: stageBackground.leadingAnchor),
            idleWaveView.trailingAnchor.constraint(equalTo: stageBackground.trailingAnchor),
            idleWaveView.topAnchor.constraint(equalTo: stageBackground.topAnchor),
            idleWaveView.bottomAnchor.constraint(equalTo: stageBackground.bottomAnchor),

            transportBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            transportBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            transportBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            transportBar.heightAnchor.constraint(equalToConstant: 64),

            progressTrack.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 14),
            progressTrack.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -14),
            progressTrack.topAnchor.constraint(equalTo: transportBar.topAnchor, constant: 8),
            progressTrack.heightAnchor.constraint(equalToConstant: 3),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            widthConstraint,

            trackTitleLabel.leadingAnchor.constraint(equalTo: transportBar.leadingAnchor, constant: 14),
            trackTitleLabel.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 8),
            trackTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -10),

            trackArtistLabel.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            trackArtistLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 2),
            trackArtistLabel.trailingAnchor.constraint(lessThanOrEqualTo: prevButton.leadingAnchor, constant: -10),

            playPauseButton.centerXAnchor.constraint(equalTo: transportBar.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: transportBar.centerYAnchor, constant: 6),
            playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),

            prevButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -8),
            prevButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 26),
            prevButton.heightAnchor.constraint(equalToConstant: 26),

            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 8),
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 26),
            nextButton.heightAnchor.constraint(equalToConstant: 26),

            rightControls.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -12),
            rightControls.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            rightControls.leadingAnchor.constraint(greaterThanOrEqualTo: nextButton.trailingAnchor, constant: 8)
        ])
        refreshTransportAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshTransportAppearance()
        applyCustomColors()
    }

    override func layout() {
        super.layout()
        layoutDocumentWidth()
    }

    private func layoutDocumentWidth() {
        let visibleH = max(200, scrollView.contentView.bounds.height)
        let pad = max(80, ceil(visibleH / 2))
        if abs(linesStack.edgeInsets.top - pad) > 1 {
            linesStack.edgeInsets = NSEdgeInsets(top: pad, left: 28, bottom: pad, right: 28)
        }
        let width = max(200, scrollView.contentView.bounds.width)
        let height = max(visibleH, linesStack.fittingSize.height)
        if documentView.frame.size != NSSize(width: width, height: height) {
            documentView.setFrameSize(NSSize(width: width, height: height))
        }
    }

    private func refreshTransportAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            progressTrack.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
            progressFill.layer?.backgroundColor = AppearanceSurfaceColors.accent.cgColor
            prevButton.refreshStyle()
            playPauseButton.refreshStyle()
            nextButton.refreshStyle()
        }
    }

    func update(
        lines: [LyricLine],
        activeIndex: Int,
        lineProgress: CGFloat,
        trackTitle: String?,
        artistName: String?,
        isPlaying: Bool,
        isPaused: Bool,
        position: TimeInterval,
        duration: TimeInterval,
        lyricsMissing: Bool
    ) {
        isPlayingState = isPlaying
        playPauseButton.image = NSImage(systemSymbolName: isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))

        let hasTrack = (trackTitle?.isEmpty == false)
        if let title = trackTitle, !title.isEmpty {
            trackTitleLabel.stringValue = title
            trackArtistLabel.stringValue = (artistName?.isEmpty == false) ? artistName! : "NotchMuse"
        } else {
            trackTitleLabel.stringValue = AppPreferences.language == .simplifiedChinese ? "未在播放" : "Not Playing"
            trackArtistLabel.stringValue = "NotchMuse"
        }

        let safeDuration = max(0, duration)
        let safePos = min(max(0, position), safeDuration > 0 ? safeDuration : max(0, position))
        timeLabel.stringValue = "\(formatClock(safePos)) / \(formatClock(safeDuration))"
        let trackWidth = progressTrack.bounds.width
        if trackWidth > 0 && safeDuration > 0 {
            progressFillWidth?.constant = trackWidth * CGFloat(safePos / safeDuration)
        } else {
            progressFillWidth?.constant = 0
        }

        if !hasTrack {
            scrollView.isHidden = true
            idleWaveView.isHidden = true
            idleWaveView.setActive(false)
            missingView.isIdlePreview = true
            missingView.isHidden = false
            missingView.setActive(!isHidden)
            return
        }

        if lines.isEmpty {
            scrollView.isHidden = true
            idleWaveView.isHidden = true
            idleWaveView.setActive(false)
            missingView.isIdlePreview = !lyricsMissing
            missingView.isHidden = false
            missingView.setActive(!isHidden)
            return
        }

        idleWaveView.isHidden = true
        idleWaveView.setActive(false)
        missingView.isHidden = true
        missingView.setActive(false)
        scrollView.isHidden = false

        if lines != currentLines {
            rebuildLines(lines)
        }
        let lineChanged = activeIndex != self.activeIndex
        if lineChanged {
            self.activeIndex = activeIndex
            highlightActiveLine(progress: lineProgress)
            scrollActiveLineToCenterIfAllowed(animated: true)
        } else if lineViews.indices.contains(activeIndex) {
            lineViews[activeIndex].sweepProgress = lineProgress
        }
    }

    private func rebuildLines(_ lines: [LyricLine]) {
        currentLines = lines
        activeIndex = -1
        linesStack.arrangedSubviews.forEach {
            linesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        lineViews.removeAll()

        let preset = AppPreferences.immersiveThemePreset
        let sweep = preset.sweepColor
        let normal = preset.normalTextColor
        for line in lines {
            let view = SweepLyricLineView(primaryText: line.text, translationText: line.translation)
            view.customSweepColor = sweep
            view.customNormalColor = normal
            linesStack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: linesStack.widthAnchor, constant: -56).isActive = true
            lineViews.append(view)
        }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
    }

    private func highlightActiveLine(progress: CGFloat) {
        for (idx, view) in lineViews.enumerated() {
            let isCurrent = idx == activeIndex
            view.isActive = isCurrent
            view.distanceFromActive = abs(idx - activeIndex)
            view.sweepProgress = isCurrent ? progress : 0
        }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
    }

    func scrollActiveLineToCenterIfAllowed(animated: Bool) {
        guard ProcessInfo.processInfo.systemUptime >= userBrowsingUntil,
              lineViews.indices.contains(activeIndex) else { return }
        layoutSubtreeIfNeeded()
        layoutDocumentWidth()
        documentView.layoutSubtreeIfNeeded()
        let target = lineViews[activeIndex]
        // Convert from unflipped NSStackView coordinates into flipped documentView coordinates!
        let centerInDoc = documentView.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), from: target)
        let visibleHeight = scrollView.contentView.bounds.height
        let maxY = max(0, documentView.bounds.height - visibleHeight)
        let clampedY = min(max(0, centerInDoc.y - visibleHeight * 0.5), maxY)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: clampedY))
            }
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: clampedY))
        }
    }

    #if DEBUG
    func debugLineCenterAndVisibleMidY(for index: Int) -> (lineMidY: CGFloat, visibleMidY: CGFloat)? {
        guard lineViews.indices.contains(index) else { return nil }
        activeIndex = index
        highlightActiveLine(progress: 0.5)
        userBrowsingUntil = 0
        scrollActiveLineToCenterIfAllowed(animated: false)
        let target = lineViews[index]
        let centerInDoc = documentView.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), from: target)
        let visibleMidY = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height * 0.5
        return (centerInDoc.y, visibleMidY)
    }
    #endif

    private func formatClock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func prevClicked() { onTransportCommand?(.previous) }
    @objc private func playPauseClicked() { onTransportCommand?(.playPause) }
    @objc private func nextClicked() { onTransportCommand?(.next) }

    @objc private func swatchClicked(_ sender: NSButton) {
        guard let dot = sender as? ThemeSwatchDotButton else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        UserDefaults.standard.set(dot.preset.rawValue, forKey: AppPreferences.immersiveThemePresetKey)
        applyCustomColors()
    }
}

private final class ImmersiveLyricsScrollView: NSScrollView {
    var onUserScroll: (() -> Void)?
    override func scrollWheel(with event: NSEvent) {
        onUserScroll?()
        super.scrollWheel(with: event)
    }
}

private final class FlippedImmersiveDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class SidebarResizeDividerView: NSView {
    var onDragDelta: ((CGFloat) -> Void)?
    var onDragEnd: ((CGFloat) -> Void)?

    private let hairline = AppearanceSurfaceView()
    private var dragStartX: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        hairline.wantsLayer = true
        hairline.surfaceColor = AppearanceSurfaceColors.border
        hairline.surfaceBorderColor = .clear
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)
        NSLayoutConstraint.activate([
            hairline.centerXAnchor.constraint(equalTo: centerXAnchor),
            hairline.topAnchor.constraint(equalTo: topAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            hairline.widthAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        onDragDelta?(event.locationInWindow.x - dragStartX)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?(event.locationInWindow.x - dragStartX)
    }
}
